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
 * Inspired much by the implementations described here:
 *   http://mila.cs.technion.ac.il/~yona/suffix_tree/
 *   http://stackoverflow.com/questions/9452701/ukkonens-suffix-tree-algorithm-in-plain-english
 *   http://pastie.org/5925809#
 *
 *
 *
 *
 */

import std.stdio;
import std.algorithm;


immutable int ALPHABET_SIZE = 256;


Node[] create_ST(string input)
{
	ulong MAXN = input.length+1; // Account for extra unique end char to be added
	char unique_end = '$';
	// Initialize all variables
	int last_added = 0;
	int pos = -1; // Iteration starts at position 0 of the input string
	int needSL = 0;
	int remainder = 0;
	int active_e = 0;
	int active_len = 0;

	Node[] tree;  // Dynamically allocated array of all nodes in the stuffix tree
	tree ~= new Node(last_added, -1,-1);
	Node active_node = tree[0];

	char[] text; // mutable dynamic array of characters in the tree string
	text.length = MAXN; // Will never be longer than input string
	
	debug assert(active_node is tree[0]);

	/*
	 * Perform extension of all characters in the supplied string
	 */
	foreach (char c; input)
	{
		debug foreach(n; tree){if (n is null){writef("n ");}else{writef("%s ", n.id);}};
		debug writeln();
		extend_ST(tree, c, last_added, pos, needSL, remainder, tree[0], active_node, active_e, active_len, text);
	}
	// Add the final unique char to make the implicit suffix tree explicit
	extend_ST(tree, unique_end, last_added, pos, needSL, remainder, tree[0], active_node, active_e, active_len, text);

	return tree;
}

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
	needSL = 0;
	remainder++;

	debug assert(root.id is 0);
	debug assert(root is tree[0]);
	debug assert(root is active_node);
	debug writeln(text);
	debug writeln("Current position is ", pos);
	debug writeln("Remainder is ", remainder);

	while (remainder > 0)
	{
		if (active_len == 0)
		{
			debug writefln("Updating active_e to %s", pos);
			active_e = pos;
		}

		/* 
		 * If active_node doesn't have edge out of it beginning with char c,
		 * create a new child node with that edge.
		 */
		debug writefln("Current active_node is %s and active_edge is c='%s'", active_node.id, text[active_e]);
		if (tree[active_node.id].next[text[active_e]] == 0)
		{
			debug writefln("Node %s does not have an outgoing edge beginning with '%s', creating a new leaf node %s", active_node.id, c, last_added);
			// Create new leaf node out of active_node
			tree ~= new Node(last_added, pos); // maxint as end 
			tree[active_node.id].next[text[active_e]] = tree[last_added-1].id;
			debug writefln("New leaf node %s added to active_node %s", tree[last_added-1].id, active_node.id);
		}
		else
		{
			debug writefln("An edge beginning with '%s' already exists out of active node %s", c, active_node.id);
			int next = tree[active_node.id].next[text[active_e]];
			debug writefln("The node with edge beginning with '%s' is %s", c, next);
			if (walk_down(tree[next], pos, active_len, active_e, active_node, tree))
			{
				// Observation 2; just modify the active point
				debug writefln("Modified the active point");
				continue;
			}
			if (text[tree[next].start + active_len] == c)
			{
				// Observation 1; the final suffix is already in the tree, only update active point and remainder
				active_len++;
				// Observation 3: if there is a node requiring a suffix link, make that link
				add_SL(active_node, needSL, tree); 
				break;
			}
			// split node
			tree ~= new Node(last_added, tree[next].start, tree[next].start + active_len);
			int split = last_added;
			tree[active_node.id].next[text[active_e]] = tree[last_added-1].id;
			// leaf node
			tree ~= new Node(last_added, pos); // maxint as end
			int leaf = last_added;
			tree[split].next[c] = leaf;
			tree[next].start += active_len;
			tree[split].next[text[tree[next].start]] = next;
			add_SL(tree[split], needSL, tree);
		}
		remainder--;
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
				active_node = root;
			}
		}
	}
}


class Node
{
	int start;
	int end;
	int slink;
	int id;
	int[ALPHABET_SIZE] next; // Initialized with zeros
	

	this(ref int last_added, int s, int e = int.max)
	{
		this.start = s;
		this.end = e;
		this.slink = 0;
		this.id = last_added++;
	}

	int edge_length(ref int pos)
	{
		return min(end, pos+1)-start;
	}
}


void add_SL(ref Node node, ref int needSL, ref Node[] tree)
{
	if (needSL > 0)
	{
		tree[needSL].slink = node.id;
	}
	needSL = node.id;
}


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


int main(string[] argv)
{
	//string s = "abcd";
	string s = "abbcd";
	writeln("Suffixes of '", s, "' to insert into the tree:");
	foreach(i, c; s)
	{
		writeln(" ", s[i..$]);
	}

	
	writeln("Creating suffix tree for ", s);
	Node[] tree = create_ST(s);
	writeln("Tree creation completed");



	return 0;
}
