#!/usr/bin/env rdmd
// Written in the D programming language
/*
 * AUTHOR: Fredrik Boulund
 * DATE: 2013-april
 * DESCRIPTION:
 * 
 * An implementation of Ukkonen's algorithm for creating suffix trees.
 * Inspired much by the implementations described here:
 *   http://mila.cs.technion.ac.il/~yona/suffix_tree/
 *   http://stackoverflow.com/questions/9452701/ukkonens-suffix-tree-algorithm-in-plain-english
 *   http://pastie.org/5925809#
 * The book "Algorithms on Strings, Trees and Sequences" by Dan Gusfield, 1997
 * was immensely useful to understand the data structure and its construction.
 *
 *
 *
 *
 */

import std.stdio;


Node* suffixless; // "global" variable, don't like it... :P

struct Path
{
	ulong start, end;
}

/**
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

/**
 * Node in the suffix tree, this implicitly contains the value of 
 * the edge pointing to this node:
 * (edge_label_start .. edge_label_end). 
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
	this() 
	{
		id = ulong.max;
		start = 0;
		end = 0;
	} 
	/// Regular constructor. Should be used for all nodes except root.
	this(ulong s, ulong e, ulong n, ref Node p)
	{
		start = s;
		end = e;
		id = n;
		parent = &p;
	}

	/**
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

	/**
	 * Compute and return the length of the edge label
	 * of the node.
	 */
	ulong get_edge_length(ref SuffixTree tree)
	{
		return this.get_end(tree) - this.start + 1;
	}

	/**
	 * Determine if edge_pos is the last position in the node's
	 * edge.
	 */
	bool is_last_char_in_edge(ref SuffixTree tree, ulong edge_pos)
	{
		if(edge_pos == this.get_edge_length(tree)-1)
			return true;
		else
			return false;
	}

	/**
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

	/**
	 * Connect two siblings together,
	 * The calling node becomes the RIGHT sibling 
	 * of the node in the argument and vice versa.
	 */
	void connect_right_sibling(ref Node node)
	{
		this.left_sibling = &node;
		node.right_sibling = &this;
	}



	/**
	 * Trace single edge
	 *
	 *
	 */
	Node* trace_single_edge(ref SuffixTree tree,
							Node* node, 
							Path str,
							ref ulong edge_pos, 
							ref ulong chars_found, 
							bool skip, 
							ref bool done)
	{
		// Default values unless other critera met
		done = true;
		edge_pos = 0;

		Node* cont_node = node.find_child(tree, tree.text[str.start]);
		if(cont_node is null)
		{
			// Search is done, string is not found!
			debug writefln("Traced edges out of node %s but found no one starting with %s", node.id, tree.text[str.start]);
			edge_pos = node.get_edge_length(tree)-1;
			chars_found = 0;
			return node;
		}

		// Found an edge out of this node with the correct first character
		node = cont_node;
		ulong length = node.get_edge_length(tree);
		ulong str_length = str.end - str.start + 1;
		// If using Ukkonnen's skip trick, just skip the length of the edge
		if(skip)
		{
			if(length <= str_length)
			{
				chars_found = length;
				edge_pos = length-1;
				if(length < str_length)
					done = false;
			}
			else
			{
				chars_found = str_length;
				edge_pos = str_length-1;
				
			}

			return node;
		}
		else
		{
			if(str_length < length) { length = str_length; }

			for(edge_pos = 1, chars_found = 1; edge_pos<length; chars_found++, edge_pos++)
			{
				if(tree.text[node.start+edge_pos] != tree.text[str.start+edge_pos])
				{
					edge_pos--;
					return node;
				}
			}
		}

		// The loop advanced edge_pos one step too much
		edge_pos--;

		if(chars_found < str_length)
		{
			done = false;
		}

		return node;
	}

}



/*
 * Trace string in the tree. Used only in tree construction.
 *
 *
 */
Node* trace_string(ref SuffixTree tree, ref Node node, Path str, ref ulong edge_pos, ref ulong chars_found, bool skip)
{
	bool done = false;
	ulong edge_chars_found = 0;

	while(!done)
	{
		edge_pos = 0;
		edge_chars_found = 0;
		node = *node.trace_single_edge(tree, &node, str, edge_pos, chars_found, skip, done);
		str.start += edge_chars_found;
		chars_found += edge_chars_found;
		debug writefln("Tracing string '%s' and found %s chars from node %s", tree.text[str.start .. str.end], chars_found, node.id);
	}
	return &node;
}

/*
 * Follow suffix link
 *
 *
 */
void follow_suffix_link(ref SuffixTree tree, ref ap active_point)
{
	// Gamma is string between node and its parent, 
	// in case node doesn't have a suffix link
	Path gamma;
	ulong chars_found = 0; // Used in trace_string

	debug writefln("Suffix link leads to '%s'", active_point.node.suffix_link);

	if(*active_point.node is tree.root)
	{
		debug writeln("Active point is tree.root, no suffix link to follow.");
		return;
	}

	if(active_point.node.suffix_link is null ||  
	   active_point.node.is_last_char_in_edge(tree, active_point.length))
	{
		if(*active_point.node.parent is tree.root)
		{
			/* 
			 * The active nodes parent is the root, so no use in following
			 * its suffix link.
			 */
			debug writeln("Active node's parent is root");
			active_point.node = &tree.root;
			return;
		}

		// Store gamma; indices of node's incoming edge
		gamma.start = active_point.node.start;
		gamma.end = active_point.node.start + active_point.length;
		// Follow parent's suffix link
		active_point.node = active_point.node.parent.suffix_link;
		// Walk down gamma steps to suffix link's child
		active_point.node = trace_string(tree, *active_point.node, gamma, active_point.length, chars_found, true);
	}
	else
	{
		// If there is a suffix link, just follow it!
		active_point.node = active_point.node.suffix_link;
		active_point.length = active_point.node.get_edge_length(tree)-1;
	}
}

/**
 * Extension rule 2
 *
 *
 *
 *
 */
Node extension2(ref SuffixTree tree, ref Node node, ulong new_node_start, ulong new_node_end, 
				ulong id, ulong edge_pos, bool new_child)
{
	// CASE 1: Create new (child) leaf node
	if(new_child) 
	{
		debug writeln("Creating new (child) leaf node");
		// Create new leaf with characters of new extension
		Node new_leaf = new Node(new_node_start, new_node_end, id+1, node);
		// Connect new_leaf as the new child of previous node
		Node child = *node.children;
		debug writefln("Child of current node is %s", node.children.id);
		while(child.right_sibling !is null)
		{
			child = *child.right_sibling;
		}
		new_leaf.connect_right_sibling(child);
		debug writefln("Added new child node %s as right sibling of %s", new_leaf.id, node.children.id);
		// Return the new leaf node
		return new_leaf;
	}
	// CASE 2: split edge and create two new nodes
	else 
	{
		debug writeln(node.start, node.get_end(tree), edge_pos);
		debug writefln("Current node parent is %s", node.parent.id);
		// Create new internal node at the split point in the edge of current node
		Node new_internal = new Node(node.start, node.get_end(tree)+edge_pos, node.id, *node.parent);
		// Update the starting index of the current node
		node.start += edge_pos+1;

		debug writefln("Created new internal node %s with start %s end %s", new_internal.id, new_internal.start, new_internal.get_end(tree));

		// Create new leaf with characters of the new extension.
		Node new_leaf = new Node(new_node_start, new_node_end, id, node);
		// Connect new_internal to where current node was
		new_internal.connect_right_sibling(node);
		node.right_sibling.connect_right_sibling(new_internal);
		node.left_sibling = null;

		debug writefln("Created new leaf node %s with start %s end %s", new_leaf.id, new_leaf.start, new_leaf.get_end(tree));
		debug writeln(new_internal.parent);
		// Connect new_internal with the parent of node
		if(*new_internal.parent.children is node)
		{
			*new_internal.parent.children = new_internal;
		}
		debug writeln("Connected new_internal with the parent of node");

		// Connect new_leaf and node as sons of new_internal
		new_internal.children = &node;
		node.parent = &new_internal;
		new_leaf.connect_right_sibling(node);

		return new_internal;
	}
}



/**
 * Suffix tree
 */
class SuffixTree
{
	string text;
	ulong e = 0; // Current global end of the tree
	Node root;
	Node[] nodes;

	this(string s)
	{
		text = s;
		root = new Node();
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
	assert(st.text[node2.start..node2.end] == "b");
	debug writefln("Node points to string 'ban' in st.text=%s starting at position %s", st.text, node2.start);

	assert(st.root.find_child(st, 'b') !is null);
}



/*
 * Creates a Suffix Tree using Ukkonen's Algorithm.
 */
SuffixTree createST(string text)
{
	char unique_char = '$';
	uint repeated_extension = 0;
	ulong extension = 0;

	if(text.length == 0)
		throw new Exception("Cannot construct suffix tree for string of of zero length.");
	debug writefln("Creating Suffix Tree with text='%s'", text);

	// Construct tree I1
	// Phase 0 of Ukkonen's algorithm
	debug writeln("Performing phase 0");
	SuffixTree st = new SuffixTree(text~unique_char);
	Node curNode = new Node(0, st.e+1, 0, st.root);
	st.nodes ~= curNode;
	st.root.children = &curNode;
	ap active_point = ap(&curNode, st.text[curNode.get_end(st)], 0);
	suffixless = null;
	extension = 2;
	debug writefln("Created node id %s with incoming edge '%s'", curNode.id, st.text[curNode.start .. curNode.end]);
	debug writefln("Node %s's parent is node %s", curNode.id, curNode.parent.id);
	debug writefln("Node %s's child is node %s", curNode.parent.id, curNode.parent.children.id);
	debug writefln("Node %s's siblings start with %s", curNode.id, curNode.right_sibling);

	/* Phases 1 .. text.length-1 */
	foreach(ulong phase; 1 .. text.length)
	{
		debug writeln("Beginning phase ", phase);
		SPA(st, active_point, phase, extension, repeated_extension);
		debug writefln("Total number of nodes is now %s", st.nodes.length);
	}
	return st;
}
unittest {
	//SuffixTree tt = createST("a");
}


/*
 * Ukkonen's Single Phase Algorithm
 */
void SPA(ref SuffixTree st, ref ap active_point, ref ulong phase, ref ulong extension, ref uint repeated_extension)
{
	uint rule_applied = 0;
	Node tmp = null;
	Path str;

	/* 
	 * 1. Increment the virtual end e to i+1. This correctly implements all implicit
	 * extensions 1 through ji)
	 */
	st.e = phase;
	debug writeln("Virtual end is ", st.e);
	debug writeln("Current active_point is: ", active_point.node.id);
	debug writefln("Active_point.node.parent is %s", active_point.node.parent.id);

	/*
	 * 2. Perform j=phase+1 extensions using SEA, 
	 * one for each phase+1 suffixes in S[1..i+1]
	 */
	while(extension <= phase+1)
	{
		// Find the end of the path from the root labeled with substring S[j..i]
		// Extend that substring with S[i+1] unless it is already there
		str.start = extension;
		str.end = phase+1;
		debug writefln("Adding extension %s..%s which is '%s'", str.start, str.end, st.text[str.start..str.end]);

		// Call Single Extension Algorithm once for each extension to ensure that extension is in the tree
		tmp = SEA(st, active_point, str, rule_applied, repeated_extension);
		if(tmp !is null)
		{
			st.nodes ~= tmp;
		}


		if(rule_applied == 3)
		{
			// Do not follow suffix link next extension because same extension is repeated
			repeated_extension = 1;
			break;
		}

		repeated_extension = 0;
		extension++;
	}
}

/*
 * Single Extension Algorithm.
 * Ensures that an extension is in the tree.
 */
Node SEA(ref SuffixTree tree, ref ap active_point, ref Path str,
		 ref uint rule_applied, ref uint completed_rule_3)
{
	ulong chars_found = 0;
	ulong path_pos = str.start;
	Node tmp;


	debug writeln("active_point.node.id ", active_point.node.id);
	// Follow suffix link if it is not the first extension after rule 3
	if(completed_rule_3 == 0)
		follow_suffix_link(tree, active_point);
	else
		debug writefln("Not following suffix link");

	// If node is root: trace whole string starting from root, else trace last char only
	if(*active_point.node is tree.root)
	{
		debug writeln("Active point is tree.root");
		active_point.node = trace_string(tree, tree.root, str, active_point.length, chars_found, false);
	}
	else
	{
		debug writefln("Active point is not tree.root, it is node id %s", active_point.node.id);
		str.start = str.end;
		chars_found = 0;
		if(active_point.node.is_last_char_in_edge(tree, active_point.length))
		{
			debug writeln("CASE 1: last matched char is last char on edge");
			// CASE 1: last matched char is last on its edge
			// Trace only last symbol of str, search in the NEXT node
			tmp = *active_point.node.find_child(tree, tree.text[str.end]);
			if(tmp !is null)
			{
				active_point.node = &tmp;
				active_point.length = 0;
				chars_found = 1;
			}
		}
		else
		{
			debug writeln("CASE 2: last matched char is NOT last on edge");
			// CASE 2: last matched char is NOT last on its edge
			// Trace only last symbol of str, search in CURRENT node
			if(tree.text[active_point.node.start + active_point.length + 1] == tree.text[str.end])
			{
				active_point.length++;
				chars_found = 1;
			}
		}
	}

	/*
	 * A whole string was found, rule 3 applies!
	 * RULE 3: We stepped down a path in the tree with no differences
	 * in the proper suffix of the current extension in the current phase.
	 * Do nothing since the suffix is already in the current tree, implicitly
	 * "baked into" an already existing path. Rule two will split this at
	 * a suitable position in another extension pass.
	 */
	if(chars_found == str.end - str.start + 1)
	{
		debug writeln("Whole string was found! Rule 3 applies; do nothing.");
		rule_applied = 3;
		if(suffixless !is null)
		{
			suffixless.suffix_link = active_point.node.parent;
			suffixless = null;
		}
		return null;
	}


	// If last found char is last of an edge, add char at next edge
	if(active_point.node.is_last_char_in_edge(tree, active_point.length) || *active_point.node is tree.root)
	{
		// Determine if to apply rule 2 (new child) or rule 1 (append to edge)
		if(active_point.node.children !is null)
		{
			debug writefln("Applying rule 2, creating new child for node %s with edge '%s'", active_point.node.id, tree.text[str.start .. str.end]);
			/*
			 * Rule 2: No path from the end of string S[j..i] starts with S[i+1],
			 * but at least one labeled path continues from the end of S[j..i].
			 * Create a new leaf edge starting from the end of S[j..i] labeled with 
			 * character S[i+1]. A new node needs to be created if S[j..i] ends inside
			 * an edge. The leaf at the end of the new leaf edge is given the number j.
			 */
			tmp = extension2(tree, *active_point.node, str.start + chars_found, str.end, active_point.length, path_pos, true);
			debug writeln("Added new leaf node.");
			rule_applied = 2;
			// If there is an internal node without suffix link (only one may exist)
			// create a suffix link from it to the parent of the current pos
			// in the tree.
			if(suffixless !is null)
			{
				debug writeln("Creating suffix link");
				suffixless.suffix_link = active_point.node;
				suffixless = null;
			}
		}

		return tmp;
	}
	else
	{
		/*
		 * Rule 1: The path ends at a leaf node (i.e. curNode has no children).
		 * Extend the substring of the leaf node of the path with S[i+1]
		 */
		// Apply extension2 split
		tmp = extension2(tree, *active_point.node, str.start + chars_found, str.end, active_point.length, path_pos, false);
		if(suffixless !is null)
		{
			tmp.suffix_link = &tree.root;
			suffixless = null;
		}
		else
		{
			// Mark as temporary waiting for a link
			suffixless = &tmp;
		}

		// Prepare active_point for next extension
		active_point.node = &tmp;
		rule_applied = 2;

		return tmp;
	}


}
unittest {
	debug writeln("----Testing createST; SPA, SEA...");
	SuffixTree tt = createST("abc");
	debug writeln("The edges of all nodes of the tree are printed:");
	debug foreach(n; tt.nodes){writefln("Node %s: '%s'", n.id, tt.text[n.start .. n.end+1]);}
	//debug printST(tt);
}


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

	debug writeln("Depth ", depth);
	if(depth>0)
	{
		// Print branches from higher nodes
		while(depth>1)
		{
			write("|");
			depth--;
		}
		// Print the current node
		debug writefln("node.start=%s, node.end=%s", node.start, node.get_end(tree));
		writefln("+%s", tree.text[node.start .. node.end]);
		
	}

	// Recursive call to all children of current node
	while(nextNode !is null)
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

	//debug printST(st);
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
