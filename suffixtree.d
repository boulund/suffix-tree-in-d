#!/usr/bin/env rdmd
// Written in the D programming language
/*
 * AUTHOR: Fredrik Boulund
 * DATE: 2013-april
 * COPYRIGHT: Copyright (C) 2013 Fredrik Boulund
 * DESCRIPTION:
 * 
 * An implementation in the D programming language of 
 * Ukkonen's algorithm for creating suffix trees.
 * Based in part on the implementations described here:
 *   http://stackoverflow.com/questions/9452701/ukkonens-suffix-tree-algorithm-in-plain-english
 *   http://mila.cs.technion.ac.il/~yona/suffix_tree/
 *   http://pastie.org/5925809#
 * The book Algorithms on Strings, Trees and Sequences by Dan Gusfield 1997
 * was immensely useful to understand the data structure and its construction.
 *
 *
 *
 *
 */

import std.stdio;



/*
 * Node in the tree, this implicitly contains the value of the edge 
 * pointing to this node (edge_label_start .. edge_label_end). 
 */
class Node
{
	Node* parent = null;
	Node* children = null;
	Node* right_sibling = null;
	Node* left_sibling = null;
	Node* suffix_link = null;
	ulong id;
	ulong start;
	ulong end;

	// Empty constructor, used for the root node
	this() { } 
	// Regular constructor. Should be used for all nodes except root.
	this(ulong s, ulong e, ulong n, ref Node p)
	{
		start = s;
		end = e;
		id = n;
		parent = &p;
	}

	/*
	 * Get the end index in the edge leading to this node.
	 * Nodes that are not leaves have different end 
	 * indices than leaves which all share the virtual end
	 * value set in st.e.
	 */
	ulong get_end(ref SuffixTree tree)
	{
		if(this.children == null)
			return tree.e;
		else
			return this.end;
	}

	/*
	 * Compute and return the length of the edge label
	 * of the node.
	 */
	ulong get_edge_length(ref SuffixTree tree)
	{
		return this.get_end(tree) - this.start + 1;
	}

	/*
	 * Determine if edge_pos is the last position in the node's
	 * edge.
	 */
	bool is_last_char_in_edge(ref SuffixTree tree, ref Node node, ulong edge_pos)
	{
		if(edge_pos == node.get_edge_length(tree)-1)
			return true;
		else
			return false;
	}

	/*
	 * Find the child of a node that begins with
	 * character c. Returns null if none exists.
	 */
	Node* find_child(ref SuffixTree tree, char c)
	{
		// Point to first child
		Node* node = this.children;
		// Scan all siblings of the first child until match
		while(node !is null && tree.text[node.start] != c)
		{
			node = node.right_sibling;
		}
		return node;

	}

	/*
	 * Connect two siblings together,
	 * The calling node becomes the RIGHT sibling 
	 * of the node in the argument and vice versa.
	 */
	void connect_right_sibling(ref Node node)
	{
		this.left_sibling = &node;
		node.right_sibling = &this;
	}

	/*
	 * Extension rule 2
	 *
	 *
	 *
	 *
	 */
	Node extension2(ref Node node, ulong new_node_start, ulong new_node_end, ulong id, ulong edge_pos, bool new_child)
	{
		if(new_child) // CASE 1: Create new leaf node
		{
			// Create new leaf with characters of new extension
			Node new_leaf = new Node(new_node_start, new_node_end, id, node);
			// Connect new_leaf as the new son of previous node
			Node child = *node.children;
			while(child.right_sibling !is null)
			{
				child = *child.right_sibling;
			}
			new_leaf.connect_right_sibling(child);
			// Return a pointer to the new leaf node
			return new_leaf;
		}
		else // CASE 2: split edge and create two new nodes
		{
			// Create new internal at the split point in the edge of current node
			Node new_internal = new Node(node.start, node.end+edge_pos, node.id, *node.parent);
			// Update the starting index of the current node
			node.start += edge_pos+1;

			// Create new leaf with characters of the new extension.
			Node new_leaf = new Node(new_node_start, new_node_end, id, node);
			// Connect new_internal to where current node was
			new_internal.connect_right_sibling(node);
			node.right_sibling.connect_right_sibling(new_internal);
			node.left_sibling = null;

			// Connect new_internal with the parent of node
			if(*new_internal.parent.children is node)
			{
				*new_internal.parent.children = new_internal;
			}

			// Connect new_leaf and node as sons of new_internal
			new_internal.children = &node;
			node.parent = &new_internal;
			new_leaf.connect_right_sibling(node);

			return new_internal;
		}
	}


	/*
	 * Trace single edge
	 *
	 *
	 */
}

/*
 * Suffix tree
 */
class SuffixTree
{
	string text;
	ulong e = 0; // Current global end of the tree
	Node root;

	this(string s)
	{
		text = s;
		root = new Node;
	}
}
unittest {
	debug writeln("----Testing Node and SuffixTree...");
	string text = "banan";
	SuffixTree st = new SuffixTree(text);
	debug writefln("SuffixTree is at address %s with st.text = '%s'", &st, st.text);
	assert(st.text == "banan");	

	Node node1 = new Node(0, st.e, 1, st.root);
	Node node2 = new Node(0, 1, 2, st.root);
	st.root.children = &node1;
	node2.connect_right_sibling(node1);
	assert(*node1.parent is st.root);
	debug writefln("node1.parent is the same as st.root");

	assert(node1.get_end(st) == node1.end);
	assert(node1.end == 0);
	st.e = st.e+3;
	assert(node1.get_end(st) != node1.end);
	assert(node1.end != 3);
	assert(st.e == 3);
	assert(st.text[node1.start..node1.end] == "");
	assert(st.text[node1.start..3] == "ban");
	debug writefln("Node points to string 'ban' in st.text=%s", st.text);

	assert(st.root.find_child(st, 'b') !is null);
}

/*
 * Active Point triple contains three pieces of information:
 *   currently active node
 *   which of the edges out of the current node we're working on
 *   the length into this edge we're supposed to extend next
 */
struct ap {
	Node* node;
	char edge;
	ulong length;
}

/*
 * Creates a Suffix Tree using Ukkonen's Algorithm.
 */
SuffixTree createST(string text)
{
	char unique_char = '$';
	char repeated_extension;
	ulong extension;
	ulong remainder = 0;

	if(text.length == 0)
		throw new Exception("Cannot construct suffix tree for string of of zero length.");

	// Construct tree I1
	// Phase 0 of Ukkonen's algorithm
	SuffixTree st = new SuffixTree(text~unique_char);
	Node curNode = new Node(0, st.e, 1, st.root);
	st.root.children = &curNode;
	ap active_point = ap(&curNode, st.text[curNode.get_end(st)], 0);

	extension = 2;

	/* Phases 1 .. text.length */
	foreach(ulong phase; 1 .. text.length-1)
	{
		debug writeln("Beginning phase ", phase);
		//SPA(st, curNode, i);
	}
	return st;
}
unittest {
	SuffixTree tt = createST("abc");
}


/*
 * Ukkonen's Single Phase Algorithm as described in Gusfield et al.
 */
void SPA(ref SuffixTree st, ref ap active_point, ref ulong phase, ref ulong extension, ref char repeated_extension)
{
	int rule_applied = 0;

	/* 1. Increment index e to i+1. This correctly implements all implicit
	 * extensions 1 through ji)
	 */
	st.e++;
	debug writeln("Printing current node:");
	debug printNode(st, *st.root.children, 1);

	/*
	 * 2. Perform j=phase+1 extensions using SEA, 
	 * one for each phase+1 suffixes in S[1..i+1]
	 */
	for(ulong j=1; j==phase+1; j++)
	{
		// Find the end of the path from the root labeled with substring S[j..i]
		// Extend that substring with S[i+1] unless it is already there
		// SEA(st, curNode)
	}
}

/+
/*
 * Single Extension Algorithm as described in Gusfield et al.
 */
void SEA(ref SuffixTree tree, ref Node curNode, uint rule_applied, uint completed_rule_3)
{
	/*
	 * Rule 1: The path ends at a leaf node (i.e. curNode has no children).
	 * Extend the substring of the leaf node of the path with S[i+1]
	 */
	if (true)
	{
	}

	/*
	 * Rule 2: No path from the end of string S[j..i] starts with S[i+1],
	 * but at least one labeled path continues from the end of S[j..i].
	 * Create a new leaf edge starting from the end of S[j..i] labeled with 
	 * character S[i+1]. A new node needs to be created if S[j..i] ends inside
	 * an edge. The leaf at the end of the new leaf edge is given the number j.
	 */
	else if ( true )
	{
	}

	/*
	 * Rule 3: We stepped down a path in the tree with no differences
	 * in the proper suffix of the current extension in the current phase.
	 * Do nothing since the suffix is already in the current tree, implicitly
	 * "baked into" an already existing path. Rule two will split this at
	 * a suitable position in another extension pass.
	 */
	else 
	{
		return;
	}

}
unittest {
	debug writeln("----Testing createST; SPA, SEA...");
	SuffixTree tt = createST("abcd");
	debug writeln("The complete tree is printed:");
	debug printST(tt);
}

+/

/*
 * Prints an entire suffix tree recursively by calling
 * printNode for each child node from the root.
 */
void printST(ref SuffixTree tree)
{
	writeln("\nroot");
	printNode(tree, tree.root, 0);
}
/*
 * Prints a single node in a suffix tree and it's children.
 */
void printNode(ref SuffixTree tree, ref Node node, ulong depth)
{
	Node* nextNode = node.children;

	if(depth>0)
	{
		// Print branches from higher nodes
		while(depth>1)
		{
			write("|");
			depth--;
		}
		// Print the current node
		writefln("+%s", tree.text[node.start .. node.end]);
		
	}

	// Recursive call to all children of current node
	while(nextNode != null)
	{
		printNode(tree, *nextNode, depth+1);
		nextNode = nextNode.right_sibling;
	}

}
unittest {
	debug writeln("----Testing printST; printNode...");
	string text = "banan";
	auto st = new SuffixTree(text);

	ulong one = 1L;
	ulong two = 2L;
	ulong three = 3L;

	Node node1 = new Node;
	node1.start = 0;
	node1.end = two;
	st.root.children = &node1;
	Node node2 = new Node;
	node2.start = 0;
	node2.end = three;
	st.root.children.right_sibling = &node2;
	Node node3 = new Node(3,4,3,node2);
	node2.children = &node3;

	debug printST(st);
}








int main(string[] argv)
{
	string s = "abbcd";
	writeln("Suffixes of ", s, ":");
	for(int i=0; i<5; i++)
	{
		writeln(s[i..5]);
	}

	return 0;
}
