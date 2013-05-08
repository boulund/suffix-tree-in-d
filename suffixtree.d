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
 *   http://stackoverflow.com/questions/9452701/ukkonens-suffix-tree-algorithm-in-plain-english
 *   http://pastie.org/5925809#
 *   http://mila.cs.technion.ac.il/~yona/suffix_tree/
 *
 *
 *
 *
 */

import std.stdio;
import std.algorithm;



Node[] create_ST(string input)
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
	tree ~= new Node(last_added, -1,-1);
	Node active_node = tree[0];

	char[] text; // Dynamic array of characters that have been added to the tree 
	text.length = input.length+1; // Will never be longer than input string
	
	debug assert(active_node is tree[0]);

	/*
	 * Perform extension of tree for each character in the supplied string
	 */
	foreach (char c; input)
	{
		debug foreach(n; tree){if (n is null){writef("n ");}else{writef("%s ", n.id);}};
		debug writeln();
		extend_ST(tree, c, last_added, pos, needSL, remainder, tree[0], active_node, active_e, active_len, text);
	}
	// Add the final unique char to make the implicit suffix tree explicit
	extend_ST(tree, unique_end, last_added, pos, needSL, remainder, tree[0], active_node, active_e, active_len, text);


	// Update the virtual end position (previously set to int.max)
	// of all leaf nodes to the final character
	foreach (node; tree)
	{
		if (node.end == int.max)
		{
			node.end = cast(int) input.length+1;
		}
	}

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
		debug writefln("Current active_node is %s and active_edge is c='%s'.", active_node.id, text[active_e]);
		try 
		{
			int next = tree[active_node.id].next[text[active_e]]; // Throws RangeError if text[active_e] is not set
			debug writefln("An edge beginning with '%s' already exists out of active node %s.", text[active_e], active_node.id);
			debug writefln("The node with edge beginning with '%s' is %s", text[active_e], next);
			if (walk_down(tree[next], pos, active_len, active_e, active_node, tree))
			{
				// Observation 2; just modify the active point
				debug writefln("Modified the active_node to %s", active_node.id);
				continue;
			}
			if (text[tree[next].start + active_len] == c)
			{
				debug writefln("The current suffix is already in the tree.");
				// Observation 1; the final suffix is already in the tree, only update active point and remainder
				active_len++;
				// Observation 3: if there is a node requiring a suffix link, make that link
				add_SL(active_node, needSL, tree); 
				debug writefln("Updated active node to %s and updating remainder and starting over.", active_node.id);
				break;
			}
			// split node (internal)
			tree ~= new Node(last_added, tree[next].start, tree[next].start + active_len);
			int internal = last_added-1;
			tree[active_node.id].next[text[active_e]] = tree[internal].id; 
			// leaf node
			tree ~= new Node(last_added, pos); // maxint as end; virtual end of all leaves!
			int leaf = last_added-1;
			debug assert(leaf != internal);
			debug writefln("Created and added new internal node %s and new leaf node %s.", internal, leaf);

			tree[internal].next[c] = leaf;
			tree[next].start += active_len;
			tree[internal].next[text[tree[next].start]] = next;
			add_SL(tree[internal], needSL, tree);
		}
		catch (core.exception.RangeError)
		{
			debug writefln("Node %s does not have an outgoing edge beginning with '%s', "
						   "creating a new leaf node %s.", active_node.id, c, last_added);
			// Create new leaf node out of active_node
			tree ~= new Node(last_added, pos); // maxint as end 
			tree[active_node.id].next[text[active_e]] = tree[last_added-1].id;
			debug writefln("New leaf node %s added to active_node %s.", tree[last_added-1].id, active_node.id);
			
		}
		remainder--;
		
		// Rule 1
		if (active_node == root && active_len > 0)
		{
			active_len--;
			active_e = pos - remainder + 1;
		}
		else
		{
			if (tree[active_node.id].slink > 0)
			{
				debug writefln("Following suffix link from %s to %s", active_node.id, active_node.slink);
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
	int[char] next; // Initialized with zeros
	

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
		debug writefln("Creating suffix link from %s to %s", needSL, node.id);
		tree[needSL].slink = node.id;
	}
	needSL = node.id;
}


bool walk_down(ref Node node, ref int pos, ref int active_len, ref int active_e, ref Node active_node, ref Node[] tree)
{
	// Skip down the current edge if long enough; skip trick!
	if (active_len >= tree[node.id].edge_length(pos))
	{
		debug writefln("Skipping down edge %s by %s", active_e, active_len);
		active_e += tree[node.id].edge_length(pos);
		active_len -= tree[node.id].edge_length(pos);
		active_node = node;
		return true;
	}
	return false;
}


void print_ST(ref Node[] tree, string s)
{
	/+
	debug foreach(n; tree){writef("%s ",n.id);};
	debug writef("\n  ");
	debug foreach(n; tree){if (n.id != 0)writef("%s ", s[n.start]);};
	debug writeln();
	+/
	print_node(tree[0], tree, s, 0);
}

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


void debug_print_ST(ref Node[] tree, string s)
{
	foreach(i, n; tree)
	{
		try
		{
			if (n.end == int.max) 
				writefln("%s %s %s %s %s", i, n.next, n.start, n.end, s[n.start .. s.length]);
			else
				writefln("%s %s %s %s %s", i, n.next, n.start, n.end, s[n.start .. n.end]);
		}
		catch (core.exception.RangeError)
		{
			writefln("%s %s %s %s %s", i, n.next, n.start, n.end, "root");
		}
	}
}

int main(string[] argv)
{
	string s;
	if (argv.length == 2)
		s = argv[1];
	else
	{
		//s = "abbc";
		//s = "abcd";
		//s = "abbc";
		//s = "cdddcdc";
		//s = "abcabxabcd";
		//s = "xabxa";
		s = "mississippi";
		writeln("Suffix Tree implementation in the D programming language");
		writeln("Fredrik Boulund 2013");
		writeln("Usage: suffixtree STRING");
	}

	writeln("Suffixes of '", s, "' to insert into the tree:");
	foreach(i, c; s)
		writeln(" ", s[i..$]);

	writeln("Creating suffix tree for '", s, "'...");
	Node[] tree = create_ST(s);
	writeln("Tree creation completed!");

	print_ST(tree, s~"$");
	debug debug_print_ST(tree, s~'$');


	return 0;
}
