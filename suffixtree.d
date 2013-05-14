#!/usr/bin/env rdmd
// Written in the D programming language
/*
 * AUTHOR: Fredrik Boulund
 * DATE: 2013-may
 * DESCRIPTION:
 * 
 * An implementation of Ukkonen's algorithm for creating suffix trees.
 * The book "Algorithms on Strings, Trees and Sequences" by Dan Gusfield, 1997
 * was immensely useful to understand the data structure and its construction.
 *
 * Inspired much by the implementations described here:
 *   http://stackoverflow.com/questions/9452701/ukkonens-suffix-tree-algorithm-in-plain-english
 *   http://pastie.org/5925809#
 *   http://mila.cs.technion.ac.il/~yona/suffix_tree/
 *
 */

import std.stdio;
import std.algorithm;
import std.getopt;



/**
 * A node in the suffix tree. 
 * Contains start and end indexes into the tree string
 * representing the characters on the edge leading to 
 * the node; no separate edge class is required.
 * The end position is by default int.max unless 
 * specified and this represents the 'virtual end'
 * used during tree construction in Ukkonen's algorithm.
 *
 */
class Node
{
	int start;
	int end;
	int slink;
	int id; 
	int pos;
	int[char] next; // hash gives O(1) lookup of outgoing edges
	

	/*
	 * Node constructor.
	 */
	this(ref int last_added, int s, int e, int p)
	{
		this.start = s;
		this.end = e;
		this.slink = 0;
		this.id = last_added++;
		this.pos = p;
	}

	/*
	 * Used during tree construction to compute edge length
	 * using the virtual end of all leaves (pos).
	 */
	int edge_length(int pos)
	{
		return min(end, pos+1)-start;
	}
}


/**
 * A suffix tree.
 */
class SuffixTree
{
	Node[] tree;
	string text;

	this(Node[] t, string s)
	{
		this.tree = t;
		this.text = s;
	}
}


/*
 * Adds a suffix link between a node and another requiring a suffix link.
 * Only used during tree construction.
 */
void add_SL(ref Node node, ref int needSL, ref Node[] tree)
{
	if (needSL > 0)
	{
		tree[needSL].slink = node.id;
	}
	needSL = node.id;
}


/*
 * Walks down the tree from a node using Ukkonen's skip trick.
 */
bool walk_down(ref Node node, ref int pos, ref int active_len, ref int active_e, ref Node active_node, ref Node[] tree)
{
	// Skip down the current edge if long enough; skip trick!
	if (active_len >= tree[node.id].edge_length(pos))
	{
		active_e += tree[node.id].edge_length(pos);
		active_len -= tree[node.id].edge_length(pos);
		active_node = node;
		return true;
	}
	return false;
}


/**
 * The entry point for creating a suffix tree from an input string.
 * Allocates memory and performs tree extensions once for each 
 * character in the input string.
 */
SuffixTree create_ST(string input)
{
	// Initialize all variables
	char unique_end = '$';
	int last_added = 0;
	int pos = -1; // Iteration starts at position 0 of the input string
	int needSL = 0;
	int remainder = 0;
	int active_e = 0;
	int active_len = 0;

	Node[] tree;  // Dynamically allocated array of all nodes in the stuffix tree
	tree ~= new Node(last_added, -1, -1, -1);
	Node active_node = tree[0];

	// Dynamic array of characters that have been added to the tree 
	// This could be refactored away to spare memory by using the
	// input string instead. 
	char[] text; 
	// Will never be longer than input string + unique end character.
	text.length = input.length+1; 
	

	/*
	 * Perform extension of tree for each character in the supplied string
	 */
	foreach (char c; input)
	{
		extend_ST(tree, c, last_added, pos, needSL, remainder, tree[0], active_node, active_e, active_len, text);
	}

	// Add the final unique char to make the implicit suffix tree explicit
	extend_ST(tree, unique_end, last_added, pos, needSL, remainder, tree[0], active_node, active_e, active_len, text);


	// Update the virtual end position (previously set to int.max)
	// of all leaf nodes to the final character of the input string.
	foreach (node; tree)
	{
		if (node.end == int.max)
		{
			node.end = cast(int) input.length+1;
		}
	}

	SuffixTree st = new SuffixTree(tree, input~unique_end);
	
	return st;
}



/*
 * Extend the suffix tree by one character.
 * This is the function that does all of the heavy lifting in 
 * the suffix tree creation. 
 */
void extend_ST(ref Node[] tree, 
		  	   char c, 
			   ref int last_added, 
			   ref int pos, 
			   ref int needSL, 
			   ref int remainder, 
			   ref Node root,
			   ref Node active_node,
			   ref int active_e,
			   ref int active_len,
			   ref char[] text)
{
	text[++pos] = c;
	needSL = 0; // Zero means "no node needs suffix link"
	remainder++;


	while (remainder > 0)
	{
		if (active_len == 0)
		{
			active_e = pos;
		}

		/* 
		 * If active_node doesn't have edge out of it beginning with char c,
		 * create a new child node with that edge.
		 */
		if (text[active_e] in tree[active_node.id].next)
		{
			int next = tree[active_node.id].next[text[active_e]];
			if (walk_down(tree[next], pos, active_len, active_e, active_node, tree))
			{
				// Observation 2: just modify the active point
				continue;
			}
			if (text[tree[next].start + active_len] == c)
			{
				// Observation 1: the final suffix is already in the tree, only update active point and remainder
				active_len++;
				// Observation 3: if there is a node requiring a suffix link, make that link
				add_SL(active_node, needSL, tree); 
				break;
			}
			// split node (internal)
			tree ~= new Node(last_added, tree[next].start, tree[next].start + active_len, -1);
			int internal = last_added-1; // The index of the new node in the tree array
			tree[active_node.id].next[text[active_e]] = tree[internal].id; 
			// leaf node
			tree ~= new Node(last_added, pos, int.max, active_e); // maxint as end; virtual end of all leaves!
			int leaf = last_added-1;

			// Make sure the pointers to next nodes are updated.
			tree[internal].next[c] = leaf;
			tree[next].start += active_len;
			tree[internal].next[text[tree[next].start]] = next;
			add_SL(tree[internal], needSL, tree);
		}
		else
		{
			// Create new leaf node out of active_node
			tree ~= new Node(last_added, pos, int.max, active_e); // maxint as end 
			tree[active_node.id].next[text[active_e]] = tree[last_added-1].id;
			
		}
		remainder--;
		
		/*
		 * Rule 1: "
		 *  If after an insertion from the active node = root, 
		 *  the active length is greater than 0, then:
		 *    active node is not changed
		 *    active length is decremented
		 *    active edge is shifted right (to the first character of the next suffix we must insert)
		 */
		if (active_node == root && active_len > 0)
		{
			active_len--;
			active_e = pos - remainder + 1;
		}
		else
		{
			if (tree[active_node.id].slink > 0)
			{
				active_node = tree[active_node.slink];
			}
			else
			{
				// The suffix link either points to root, which is 0 (or there was none).
				active_node = root;
			}
		}
	}
}



/**
 * Prints a complete suffix tree by calling print_node one time
 * for each node out of the root node.
 */
void print_ST(ref SuffixTree st)
{
	print_node(st.tree[0], st.tree, st.text, 0);
}

/**
 * Prints a node and all its children nodes by calling itself recursively.
 */
void print_node(Node node, Node[] tree, string s, int depth)
{
	int d = depth;
	if (depth == 0)
	{
		writeln("root");		
	}
	else if (depth > 0)
	{
		// Print branches from higher nodes
		foreach(l; 1..d)
		{
			write("|");
			d--;
		}
		write("+");
		// Print the actual node
		writefln("%s", s[tree[node.id].start .. tree[node.id].end]);
	}
	// Print all child nodes
	foreach(n; node.next)
	{
		if (n != 0)
		{
			print_node(tree[n], tree, s, depth+1);
		}
	}
}



/**
 * Performs a search for substring in the suffix tree.
 */
int[] search_ST(ref SuffixTree st, string s)
{
	int next_node = 0;
	int matched_characters = 0;
	int[] positions;

	if (s.length == 0) { return positions;}


	if (s[0] in st.tree[0].next)
	{
		matched_characters++;
		next_node = st.tree[0].next[s[0]];

		if (search_node(st, next_node, s, matched_characters, positions))
			return positions;
	}

	positions.length = 0;
	return positions;
}


int[] find_leaf_positions(ref SuffixTree st, int cur_node)
{
	int[] positions;
	if (st.tree[cur_node].next.length == 0)
	{
		positions ~= st.tree[cur_node].pos;
		return positions;
	}
	foreach (n; st.tree[cur_node].next)
	{
		positions ~= find_leaf_positions(st, n);
	}
	return positions;
}



bool search_node(ref SuffixTree st, int cur_node, string s, ref int matched_characters, ref int[] positions)
{

	if (matched_characters == s.length)
	{
		positions ~= find_leaf_positions(st, cur_node);
		return true;
	}
	/*
	 * Go through all positions on the edge of this node except the first,
	 * since it has already been matched in the outgoing edge from the
	 * previous node. 
	 */
	foreach (pos; st.tree[cur_node].start+1 .. st.tree[cur_node].end)
	{

		if (s[matched_characters] == st.text[pos])
		{
			matched_characters++;

			// Don't continue searching if complete query string is matched now.
			if (matched_characters >= s.length)
			{
				// Append the current position on this edge, as this is 
				// also a position where the entire search string is
				// begins as a substring of the tree string.
				positions ~= find_leaf_positions(st, cur_node);
				return true;
			}
		}
		else
		{
			return false;
		}
		
	}


	/*
	 * Finished searching the incoming edge now, check if there is an outgoing
	 * edge beginning with the next character in the search string.
	 */
	if (matched_characters < s.length && s[matched_characters] in st.tree[cur_node].next)
	{
		// Don't continue searching if complete query string is matched now.
		if (matched_characters == s.length)
		{
			// Find the start indexes of all leaf nodes beneath this one
			// to find all occurences of this suffix in the tree string.
			//positions ~= st.tree[cur_node].pos;
			positions ~= find_leaf_positions(st, cur_node); 
			return true;
		}
		else 
		{
			cur_node = st.tree[cur_node].next[s[matched_characters]];
			return search_node(st, cur_node, s, ++matched_characters, positions);
		}
	}
	else if (matched_characters == s.length) 
	{
		positions ~= find_leaf_positions(st, cur_node);
		return true;
	}
	return false;
}



unittest
{
	string s = "bananas";
	SuffixTree st = create_ST(s);

	int[] positions;
	int[] correct_positions = [0, 1, 2, 3, 4, 5, 6, 7];
	
	// Searching for all suffixes in the tree string
	foreach(i, c; s)
	{
		positions = search_ST(st, s[i..$]);
		assert(positions[0] == correct_positions[i]);
	}

	// Search for a string NOT in the tree
	positions = search_ST(st, "anab");
	assert(positions.length == 0);

	// Search for all substrings that are not suffixes
	foreach(i, c; s)
	{
		positions = search_ST(st, s[i..$]);
		assert(positions[0] == i);
	}
}




/*********************************************************
 *                        MAIN                           *
 *********************************************************/
int main(string[] argv)
{
	string s;
	string search;
	if (argv.length == 2)
		s = argv[1];
	else if (argv.length == 3)
	{
		s = argv[1];
		search = argv[2];
	}
	else
	{
		//s = "abbc";
		//s = "abcd";
		//s = "abbc";
		//s = "cdddcdc";
		//s = "abcabxabcd";
		//s = "xabxa";
		//s = "mississippi";
		//search = "ipp";
		writeln("Suffix Tree implementation in the D programming language");
		writeln("Fredrik Boulund 2013");
		writeln("Usage: suffixtree STRING [QUERY]");
		return 0;
	}

	writeln("Suffixes of '", s, "' to insert into the tree:");
	foreach(i, c; s)
		writeln(" ", s[i..$]);

	writeln("Creating suffix tree for '", s, "'...");
	SuffixTree st = create_ST(s);
	writeln("Tree creation completed!");

	print_ST(st);

	int[] positions = search_ST(st, search);
	if (positions.length == 0)
	{
		writefln("No matches to '%s' found in the tree string '%s'", search, st.text);
	}
	else
	{
		writeln("Found matches to '", search, "' at the following positions");
		writeln(positions);
	}

	return 0;
}
