/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
*/


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBUserInterfaceController.h"
#import "IMBLibraryController.h"
#import "IMBNodeTreeController.h"
#import "IMBObjectArrayController.h"
#import "IMBOutlineView.h"
#import "IMBConfig.h"
#import "IMBNode.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBUserInterfaceController ()

- (void) _startObservingLibraryController;
- (void) _stopObservingLibraryController;

- (NSMutableDictionary*) _preferences;
- (void) _setPreferences:(NSMutableDictionary*)inDict;
- (void) _saveStateToPreferences;
- (void) _loadStateFromPreferences;

- (NSMutableArray*) _expandedNodeIdentifiers;
- (void) _nodesWillChange;
- (void) _nodesDidChange;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBUserInterfaceController

@synthesize libraryController = _libraryController;

@synthesize nodeTreeController = ibNodeTreeController;
@synthesize nodeOutlineView = ibNodeOutlineView;
@synthesize nodePopupButton = ibNodePopupButton;
@synthesize selectedNodeIdentifier = _selectedNodeIdentifier;
@synthesize expandedNodeIdentifiers = _expandedNodeIdentifiers;

@synthesize objectArrayController = ibObjectArrayController;
@synthesize objectTabView = ibObjectTabView;
@synthesize objectTableView = ibObjectTableView;
@synthesize objectImageBrowserView = ibObjectImageBrowserView;
@synthesize objectViewType = _objectViewType;
@synthesize objectIconSize = _objectIconSize;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_selectedNodeIdentifier = nil;
		_expandedNodeIdentifiers = nil;
		_isRestoringState = NO;
	}
	
	return self;
}


- (void) awakeFromNib
{
	ibObjectArrayController.objectUnitSingular = NSLocalizedString(@"objectUnitSingular",@"Name of object media type (singular)");
	ibObjectArrayController.objectUnitPlural = NSLocalizedString(@"objectUnitPlural",@"Name of object media type (singular)");
	
	// Load the last known state from preferences, and save once the app is about to quit...
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_saveStateToPreferences) 
		name:NSApplicationWillTerminateNotification 
		object:nil];
}


- (void) dealloc
{
	[self _stopObservingLibraryController];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	IMBRelease(_libraryController);
	IMBRelease(_selectedNodeIdentifier);
	IMBRelease(_expandedNodeIdentifiers);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (void) setLibraryController:(IMBLibraryController*)inLibraryController
{
	[self _stopObservingLibraryController];

	id old = _libraryController;
	_libraryController = [inLibraryController retain];
	[old release];
	
	[self _startObservingLibraryController];
	[self _loadStateFromPreferences];
}


- (NSString*) mediaType
{
	return self.libraryController.mediaType;
}


- (void) _startObservingLibraryController
{
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_nodesWillChange) 
		name:kIMBNodesWillChangeNotification 
		object:_libraryController];
		
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_nodesDidChange) 
		name:kIMBNodesDidChangeNotification 
		object:_libraryController];
}


- (void) _stopObservingLibraryController
{
	[[NSNotificationCenter defaultCenter] 
		removeObserver:self 
		name:kIMBNodesWillChangeNotification 
		object:_libraryController];

	[[NSNotificationCenter defaultCenter] 
		removeObserver:self 
		name:kIMBNodesDidChangeNotification
		object:_libraryController];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSMutableDictionary*) _preferences
{
	NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
	return [NSMutableDictionary dictionaryWithDictionary:[classDict objectForKey:self.mediaType]];
}


- (void) _setPreferences:(NSMutableDictionary*)inDict
{
	NSMutableDictionary* classDict = [IMBConfig prefsForClass:self.class];
	[classDict setObject:inDict forKey:self.mediaType];
	[IMBConfig setPrefs:classDict forClass:self.class];
}


- (void) _saveStateToPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:self.expandedNodeIdentifiers forKey:@"expandedNodeIdentifiers"];
	[stateDict setObject:self.selectedNodeIdentifier forKey:@"selectedNodeIdentifier"];
	[self _setPreferences:stateDict];
}


- (void) _loadStateFromPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	
	self.expandedNodeIdentifiers = [stateDict objectForKey:@"expandedNodeIdentifiers"];
	self.selectedNodeIdentifier = [stateDict objectForKey:@"selectedNodeIdentifier"];
	
	float splitviewPosition = [[stateDict objectForKey:@"splitviewPosition"] floatValue];
	if (splitviewPosition > 0.0) [ibSplitView setPosition:splitviewPosition ofDividerAtIndex:0];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSOutlineView Delegate


// If the user is  expanding an item in the IMBOutlineView then ask the delegate of the library controller if 
// we are allowed to expand the node. If expansion was not triggered by a user event, but by the controllers
// then always allow it...

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldExpandItem:(id)inItem
{
	BOOL shouldExpand = YES;
	
	if (!_isRestoringState)
	{
		id delegate = self.libraryController.delegate;
		
		if ([delegate respondsToSelector:@selector(controller:shouldExpandNode:)])
		{
			IMBNode* node = [inItem representedObject];
			shouldExpand = [delegate controller:self.libraryController shouldExpandNode:node];
		}
	}
	
	return shouldExpand;
}


// Expanding was allowed, so instruct the library controller to add subnodes to the node if necessary...

- (void) outlineViewItemWillExpand:(NSNotification*)inNotification
{
//	if (!_isRestoringState)
	{
		id item = [[inNotification userInfo] objectForKey:@"NSObject"];
		IMBNode* node = [item representedObject];
		[self.libraryController expandNode:node];
	}
}


// When nodes were expanded or collapsed, then store the current state of the user interface...

- (void) _setExpandedNodeIdentifiers
{
	if (!_isRestoringState && !self.libraryController.isReplacingNode)
	{
		self.expandedNodeIdentifiers = [self _expandedNodeIdentifiers];
	}
}

- (void) outlineViewItemDidExpand:(NSNotification*)inNotification
{
	[self _setExpandedNodeIdentifiers];
}

- (void) outlineViewItemDidCollapse:(NSNotification*)inNotification
{
	[self _setExpandedNodeIdentifiers];
}


//----------------------------------------------------------------------------------------------------------------------


// Ask the library delegate if we may change the selection...

- (BOOL) outlineView:(NSOutlineView*)inOutlineView shouldSelectItem:(id)inItem
{
	BOOL shouldSelect = YES;

	if (!_isRestoringState)
	{
		IMBNode* node = [inItem representedObject];
		id delegate = self.libraryController.delegate;
		
		if ([delegate respondsToSelector:@selector(controller:shouldSelectNode:)])
		{
			shouldSelect = [delegate controller:self.libraryController shouldSelectNode:node];
		}
	}
	
	return shouldSelect;	
}


// If the selection just changed due to a direct user event (clicking), then instruct the library controller 
// to populate the node (if necessary) and remember the identifier of the selected node...

- (void) outlineViewSelectionDidChange:(NSNotification*)inNotification;
{
	if (!_isRestoringState && !self.libraryController.isReplacingNode)
	{
		NSInteger row = [ibNodeOutlineView selectedRow];
		id item = row>=0 ? [ibNodeOutlineView itemAtRow:row] : nil;
		IMBNode* node = [item representedObject];

		if (node)
		{
			id delegate = self.libraryController.delegate;
			
			if ([delegate respondsToSelector:@selector(controller:willSelectNode:)])
			{
				[delegate controller:self.libraryController willSelectNode:node];
			}
			
			[self.libraryController selectNode:node];
			self.selectedNodeIdentifier = node.identifier;
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSSplitView Delegate


// Store the current divider position in the preferences...

- (CGFloat) splitView:(NSSplitView*)inSplitView constrainSplitPosition:(CGFloat)inPosition ofSubviewAt:(NSInteger)inIndex
{
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:[NSNumber numberWithFloat:inPosition] forKey:@"splitviewPosition"];
	[self _setPreferences:stateDict];

	return inPosition;
}


// When resising the splitview, then make sure that only the bottom part (object view) gets resized, and 
// that the IMBOutlineView is not affected...

- (void) splitView:(NSSplitView*)inSplitView resizeSubviewsWithOldSize:(NSSize)inOldSize
{
    NSView* topView = [[inSplitView subviews] objectAtIndex:0];  
    NSView* bottomView = [[inSplitView subviews] objectAtIndex:1];
    float dividerThickness = [inSplitView dividerThickness]; 
	
    NSRect newFrame = [inSplitView frame];   
	                
    NSRect topFrame = [topView frame];                    
	topFrame.size.width = newFrame.size.width;
   
    NSRect bottomFrame = [bottomView frame];    
    bottomFrame.origin = NSMakePoint(0,0);  
    bottomFrame.size.height = newFrame.size.height - topFrame.size.height - dividerThickness;
    bottomFrame.size.width = newFrame.size.width;          
    bottomFrame.origin.y = topFrame.size.height + dividerThickness; 
 
	[topView setFrame:topFrame];
    [bottomView setFrame:bottomFrame];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Saving & Restoring State


// Get the identifiers of all currently expanded nodes. The result is a flat array, which is needed in the method
// _restoreUserInterfaceState to try to restore the state of the user interface...

- (NSMutableArray*) _expandedNodeIdentifiers
{
	NSMutableArray* expandedNodeIdentifiers = [NSMutableArray array];
	
	NSInteger n = [ibNodeOutlineView numberOfRows];
	
	for (NSInteger i=0; i<n; i++)
	{
		id item = [ibNodeOutlineView itemAtRow:i];
		
		if ([ibNodeOutlineView isItemExpanded:item])
		{
			IMBNode* node = [item representedObject];
			[expandedNodeIdentifiers addObject:node.identifier];
		}
	}

	return expandedNodeIdentifiers;
}


// Get IMBNode at specified table row...

- (IMBNode*) _nodeAtRow:(NSInteger)inRow
{
	id item = [ibNodeOutlineView itemAtRow:inRow];
	IMBNode* node = [item representedObject];
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// Called in response to a IMBNodesWillChangeNotification notification. Set a flag that helps us to do the right 
// thing in the IMBOutlineView delegate methods. If nodes are currently being replaced, then we will allow any 
// changes, because those changes were not initiated by user events...

- (void) _nodesWillChange
{

}


//----------------------------------------------------------------------------------------------------------------------


// Called in response to a IMBNodesDidChangeNotification notification. Restore expanded state from the saved info.
// We now have new node instances, but we can use the identifiers to locate the correct ones. First expand nodes
// as needed, then select the correct node...

- (void) _nodesDidChange
{
	NSInteger i,rows,count;
	IMBNode* node;
	NSString* identifier;
	
	// Temporarily disable storing of saved state (we only want that when the user actuall clicks in the UI...
	
	_isRestoringState = YES;
	
	// Restore the expanded nodes...
	
	NSMutableArray* expandedNodeIdentifiers = [NSMutableArray arrayWithArray:self.expandedNodeIdentifiers];
	
	while (count = [expandedNodeIdentifiers count])
	{
		rows = [ibNodeOutlineView numberOfRows];
		
		for (i=0; i<rows; i++)
		{
			node = [self _nodeAtRow:i];
			identifier = node.identifier;
			
			if ([expandedNodeIdentifiers indexOfObject:identifier] != NSNotFound)
			{
				[ibNodeOutlineView expandItem:[ibNodeOutlineView itemAtRow:i]];
				[expandedNodeIdentifiers removeObject:identifier];
				break;
			}
		}
		
		if ([expandedNodeIdentifiers count] == count)
		{
			break;
		}
	}
	
	// Restore the selected node. Walk through all visible nodes. If we find the correct one then select it...
	
	rows = [ibNodeOutlineView numberOfRows];
	
	for (i=0; i<rows; i++)
	{
		node = [self _nodeAtRow:i];
		identifier = node.identifier;
		
		if ([identifier isEqualToString:self.selectedNodeIdentifier])
		{
			[self selectNode:node];
		}
	}
	
	// We are done, now the user is once again in charge...
	
	_isRestoringState = NO;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) selectNode:(IMBNode*)inNode
{
	if (inNode)
	{	
		NSIndexPath* indexPath = inNode.indexPath;
		[ibNodeTreeController setSelectionIndexPath:indexPath];
		[self.libraryController selectNode:inNode];
	}	
}


- (IMBNode*) selectedNode
{
	NSArray* selectedNodes = [ibNodeTreeController selectedObjects];
	
	if ([selectedNodes count] > 0)
	{
		return [selectedNodes objectAtIndex:0];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Adding & Removing


- (BOOL) canReload
{
	return YES;
}


- (IBAction) reload:(id)inSender
{

}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) canAddNode
{
	return YES;
}


- (IBAction) addNode:(id)inSender
{

}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) canRemoveNode
{
	return NO;
}


- (IBAction) removeNode:(id)inSender
{

}


//----------------------------------------------------------------------------------------------------------------------


@end
