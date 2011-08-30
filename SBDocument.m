//
//  SBDocument.m
//  BZ Soundboard
//
//  Created by Mac-arena the Bored Zo on 2005-11-15.
//  Copyright 2005 Mac-arena the Bored Zo. All rights reserved.
//

#import "SBDocument.h"

#import "NSURLAdditions.h"
#import "NSMutableArray+EasyMutation.h"
#import "QTMovie+AudioDevice.h"
#import "NSMatrix+RowAndColumnAccess.h"
#import "BZGeometry.h"

#import "BZMovieButtonCell.h"
#import "BZNotifyingMatrix.h"
#import "BZResizeNotifyingWindow.h"
#import "AudioDevice.h"

#include <c.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <float.h>

#pragma mark NSError values

//the domain for all BZ Soundboard errors.
#define SOUNDBOARD_ERROR_DOMAIN @"BZSoundboard"

//error codes.
enum {
	NOT_AN_ERROR_NOTHING_TO_SEE_HERE_MOVE_ALONG, //yes, I know I can just say 'CANT_READ_PLIST = 1', but I thought this was funnier :)
	CANT_READ_PLIST
};

#pragma mark Things in .sboard files

//a .sboard file is a serialised dictionary.
//these are the keys in that dictionary.
#define LAST_DEVICE_KEY @"UID of last selected output device"
#define LAST_VOLUME_KEY @"Last selected volume level (0..1)"
#define CONTENTS_OF_SOUNDBOARD_KEY @"Rows in soundboard"
#define WINDOW_LOCATION_KEY @"Origin point of soundboard window" /*XXX*/
#define MATRIX_DIMENSIONS_KEY @"Number of columns and rows in matrix" /*XXX*/
#define CELL_SIZE_KEY @"Cell size" /*XXX*/
//not a key.
#define NUMBER_OF_SBOARD_KEYS 5U

//a soundboard can have empty cells.
//this is a guaranteed invalid URL/path, to be found in the value for CONTENTS_OF_SOUNDBOARD_KEY, indicating such a cell.
#define EMPTY_CELL @"//empty_cell"

//these are the defaults because I like them. :)
#define DEFAULT_CELL_SIZE (NSSize){ 82.0f, 66.0f }
#define DEFAULT_MATRIX_DIMENSIONS (NSSize){ 6.0f, 5.0f }

#pragma mark Undo constants

//keys in undo-description dictionaries.
#define UNDO_ACTIONNAME       @"Action name"
#define UNDO_OLDVALUE         @"Old value"
#define UNDO_NEWVALUE         @"New value"
#define UNDO_CELL             @"Cell"
#define UNDO_CELL_COLUMNINDEX @"X co-ordinate of cell"
#define UNDO_CELL_ROWINDEX    @"Y co-ordinate of cell"

//action names.
#define UNDO_MATRIXDIMENSIONSCHANGED @"Change Soundboard Dimensions"
//note: old/new value in UNDO_CELLSIZECHANGED includes intercell spacing.
#define UNDO_CELLSIZECHANGED @"Change Cell Size"
#define UNDO_CELLMOVIECHANGED @"Change Movie in Cell"
#define UNDO_VOLUMECHANGED @"Change Volume"
#define UNDO_DEVICECHANGED @"Change Output Device"

#import "CommonNotifications.h"

@interface SBDocument (PRIVATE)

- (void)fillOutDevicesPopUp;

- (QTMovie *)movieAtRow:(unsigned)row column:(unsigned)col;

- (void)addColumnsToMatrix:(unsigned)numCols;
- (void)addRowsToMatrix:(unsigned)numRows;

- (void)removeColumnsFromMatrix:(unsigned)numCols;
- (void)removeRowsFromMatrix:(unsigned)numRows;

- (void)applySizeDeltaToMatrix:(NSSize)sizeDelta;

@end

@interface SBDocument (PRIVATE_BindingsAccessors)

//relative to (used by) the pop-up menu.
- (int)currentDeviceSelectionIndex;
- (void)setCurrentDeviceSelectionIndex:(int)newIndex;

- (float)volume;
- (void)setVolume:(float)newVol;

@end

@implementation SBDocument

- init {
	if (self = [super init]) {
		plistRepresentation = [[NSMutableDictionary alloc] initWithCapacity:NUMBER_OF_SBOARD_KEYS];
		plistFormat = NSPropertyListBinaryFormat_v1_0; //for new documents

		undoEnabled = YES;
	}
	return self;
}

- (NSString *)windowNibName {
	return @"SBDocument";
}
- (void)awakeFromNib {
	//populate the devices pop-up with all the devices.
	[self fillOutDevicesPopUp];
	
	//IB has our top-left cell highlighted and on. this works around that.
	BZMovieButtonCell *cell = [moviesMatrix cellAtRow:0 column:0];
	[cell setHighlighted:NO];
	[cell setState:NSOffState];
	//get ready for resizing.
	[moviesMatrix setCellClass:[BZMovieButtonCell class]];
	cell = [cell copy];
	[moviesMatrix setPrototype:cell];
	[cell release];

	undoEnabled = NO;

	//observe for changes in the movie of every cell.
	NSArray *allCells = [moviesMatrix cells];
	NSEnumerator *cellsEnum = [allCells objectEnumerator];
	while((cell = [cellsEnum nextObject])) {
		[cell addObserver:self
			   forKeyPath:@"movie"
				  options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
				  context:NULL];
	}
	
	//set the window's frame (origin and size), and the dimensions of the matrix.
	if([self fileName]) {
		NSString *windowLocationString = [plistRepresentation objectForKey:WINDOW_LOCATION_KEY];
		NSString *matrixDimensionsString = [plistRepresentation objectForKey:MATRIX_DIMENSIONS_KEY];
		NSRect frame = {
			.origin = windowLocationString
				? NSPointFromString(windowLocationString)
				: NSZeroPoint,
			.size = matrixDimensionsString
				? NSSizeFromString(matrixDimensionsString)
				: DEFAULT_MATRIX_DIMENSIONS
		};

		[moviesMatrix renewRows:frame.size.height columns:frame.size.width];

		NSString *cellSizeString = [plistRepresentation objectForKey:CELL_SIZE_KEY];
		NSSize cellSize = cellSizeString
		                ? NSSizeFromString([plistRepresentation objectForKey:CELL_SIZE_KEY])
		                : DEFAULT_CELL_SIZE;
		frame.size.width  *= cellSize.width;
		frame.size.height *= cellSize.height;

		//the gutter around the matrix.
		NSRect originalWindowFrame = [playerWindow frame];
		NSRect originalMatrixFrame = [moviesMatrix frame];
		frame.size.width  += originalWindowFrame.size.width  - originalMatrixFrame.size.width;
		frame.size.height += originalWindowFrame.size.height - originalMatrixFrame.size.height;

		[playerWindow setFrame:frame display:NO];
		if(!windowLocationString)
			[playerWindow center];
	}

	//be notified when the user resizes our window.
	//we are already the window's delegate in the nib.
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		   selector:@selector(windowLiveResizeWillBegin:)
			   name:BZWindowLiveResizeWillBegin
			 object:playerWindow];
	[nc addObserver:self
		   selector:@selector(windowLiveResizeDidEnd:)
			   name:BZWindowLiveResizeDidEnd
			 object:playerWindow];

	//get the saved contents of the soundboard.
	NSRange range = { 0U, [moviesMatrix numberOfRows] };
	NSArray *rows = [plistRepresentation objectForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	if(rows && ([rows count] > range.length))
		rows = [rows subarrayWithRange:range];

	//in the loop, we use this range to crop the rows to the proper number of columns.
	range.length = [moviesMatrix numberOfColumns];

	//create the movies, and fill them into the matrix.
	NSEnumerator *rowsEnum = [rows objectEnumerator];
	NSArray *row;
	unsigned rowIndex = 0U;
	while((row = [rowsEnum nextObject])) {
		NSEnumerator *rowEnum = [row objectEnumerator];
		NSObject *obj;
		unsigned colIndex = 0U;
		while((obj = [rowEnum nextObject])) {
			BZMovieButtonCell *cell = [moviesMatrix cellAtRow:rowIndex column:colIndex];

			[cell setMovie:[self movieAtRow:rowIndex column:colIndex]];
			[cell setNotificationObject:self];

			if(++colIndex >= range.length)
				break;
		}

		++rowIndex;
	}

	NSString *lastDeviceUID = [plistRepresentation objectForKey:LAST_DEVICE_KEY];
	if(lastDeviceUID) {
		int lastSelectedIndex = [devicesPopUp indexOfItemWithRepresentedObject:lastDeviceUID];
		//make sure the device still exists. if not, stay with the default device (already selected in the nib).
		if(lastSelectedIndex < 0) {
#warning XXX warn the user here
			lastSelectedIndex = 0;
		}
		
		//store it in our ivar.
		[self setCurrentDeviceSelectionIndex:lastSelectedIndex];
	}

	NSNumber *volumeNum = [plistRepresentation objectForKey:LAST_DEVICE_KEY];
	if(volumeNum && [volumeNum isKindOfClass:[NSString class]]) {
		NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
		volumeNum = [formatter numberFromString:(NSString *)volumeNum];
		[formatter release];
	}
	[self setVolume:(volumeNum ? [volumeNum floatValue] : 1.0f)];

	undoEnabled = YES;

	[moviesMatrix registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

	[playerWindow makeKeyAndOrderFront:nil];
}

- (void)dealloc {
	[plistRepresentation release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	NSArray *allCells = [moviesMatrix cells];
	NSEnumerator *cellsEnum = [allCells objectEnumerator];
	BZMovieButtonCell *cell;
	while((cell = [cellsEnum nextObject]))
		[cell removeObserver:self forKeyPath:@"movie"];

	[super dealloc];
}

#pragma mark NSDocument file I/O

- (NSDictionary *)fileAttributesToWriteToURL:(NSURL *)absoluteURL
									  ofType:(NSString *)typeName
							forSaveOperation:(NSSaveOperationType)saveOperation
						 originalContentsURL:(NSURL *)absoluteOriginalContentsURL
									   error:(NSError **)outError
{
	NSMutableDictionary *dict = [[super fileAttributesToWriteToURL:absoluteURL
															ofType:typeName
												  forSaveOperation:saveOperation
											   originalContentsURL:absoluteOriginalContentsURL
															 error:outError] mutableCopy];
	if(dict) {
		//radar bug #4424348
//		[dict setObject:NSFileTypeForHFSTypeCode('SBRD') forKey:NSFileHFSTypeCode];
//		[dict setObject:NSFileTypeForHFSTypeCode('BZSB') forKey:NSFileHFSCreatorCode];

		[dict setObject:[NSNumber numberWithUnsignedLong:'SBRD'] forKey:NSFileHFSTypeCode];
		[dict setObject:[NSNumber numberWithUnsignedLong:'BZSB'] forKey:NSFileHFSCreatorCode];
		[dict autorelease];
	}
	return dict;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	NSString *errorString = nil;
	[plistRepresentation release];
	plistRepresentation = [[NSPropertyListSerialization propertyListFromData:data
															mutabilityOption:NSPropertyListMutableContainers
																	  format:&plistFormat
															errorDescription:&errorString] retain];
	if(!plistRepresentation) {
		if(outError) {
			NSString *filename = [self fileName];
			plistRepresentation = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:NSLocalizedString(@"Could not open file", /*comment*/ nil), [filename lastPathComponent]], NSLocalizedDescriptionKey,
				errorString, NSLocalizedFailureReasonErrorKey,
				[self fileURL],  NSURLErrorKey,
				filename, NSFilePathErrorKey,
				nil];
			NSError *error = [NSError errorWithDomain:SOUNDBOARD_ERROR_DOMAIN
												 code:CANT_READ_PLIST
											 userInfo:plistRepresentation];
			*outError = error;
		}
		return NO;
	}

	return YES;
}

- (NSData *)dataOfType:(NSString *)type error:(NSError **)outError {
	NSArray *lastRows = [plistRepresentation objectForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	unsigned lastRowsCount = [lastRows count];

	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:lastRowsCount];

	unsigned numberOfColsInMatrix = [moviesMatrix numberOfColumns];
	unsigned numberOfRowsInMatrix = [moviesMatrix numberOfRows];

	NSRange rowsCrop = { 0U, 0U };

	unsigned rowIndex = 0U;
	NSMutableArray *row;
	while(rowIndex < numberOfRowsInMatrix) {
		if(rowIndex < lastRowsCount)
			row = [[lastRows objectAtIndex:rowIndex] mutableCopy];
		else
			row = [[NSMutableArray alloc] init];

		//we want to crop any empty cells off of the end.
		NSRange columnsCrop = { 0U, 0U };

		for(unsigned colIndex = 0U; colIndex < numberOfColsInMatrix; ++colIndex) {
			BZMovieButtonCell *cell = [moviesMatrix cellAtRow:rowIndex column:colIndex];

			NSObject *value;
			QTMovie *movie = [cell movie];
			if(movie) {
				//we know the movie has a filename because we create them with filenames, as does BZMovieButtonCell.
				NSString *path = [movie attributeForKey:QTMovieFileNameAttribute];
				value = [[NSURL fileURLWithPath:path] dockDescription];
			} else {
				value = EMPTY_CELL;
			}

			[row setObject:value atIndex:colIndex];
		}

		//crop off any empty cells at the end.
		//this may leave the row empty, which is fine.
		unsigned rowCount = [row count];
		for(unsigned iPlusOne = rowCount; iPlusOne > 0U; --iPlusOne) {
			unsigned i = iPlusOne - 1U;
			if(![[row objectAtIndex:i] isEqual:EMPTY_CELL]) {
				columnsCrop.location = iPlusOne;
				break;
			}
		}
		columnsCrop.length = rowCount - columnsCrop.location;
		if(columnsCrop.length)
			[row removeObjectsInRange:columnsCrop];

		++rowIndex;
		
		//start rows crop here.
		if([row count])
			rowsCrop.location = rowIndex;

		[rows addObject:row];
		[row release];
	}

	rowsCrop.length = [rows count] - rowsCrop.location;
	if(rowsCrop.length)
		[rows removeObjectsInRange:rowsCrop];

	[plistRepresentation setObject:rows forKey:CONTENTS_OF_SOUNDBOARD_KEY];

	[plistRepresentation setObject:NSStringFromPoint([playerWindow frame].origin) forKey:WINDOW_LOCATION_KEY];
	[plistRepresentation setObject:NSStringFromSize((NSSize){ [moviesMatrix numberOfColumns], [moviesMatrix numberOfRows] }) forKey:MATRIX_DIMENSIONS_KEY];
	[plistRepresentation setObject:NSStringFromSize([moviesMatrix cellSize]) forKey:CELL_SIZE_KEY];

	NSString *errorString = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:plistRepresentation
															  format:plistFormat
													errorDescription:&errorString];
	if(!data) {
		if(outError) {
			NSString *filename = [self fileName];
			plistRepresentation = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:NSLocalizedString(@"Could not save file", /*comment*/ nil), [filename lastPathComponent]], NSLocalizedDescriptionKey,
				errorString, NSLocalizedFailureReasonErrorKey,
				[self fileURL],  NSURLErrorKey,
				filename, NSFilePathErrorKey,
				nil];
			NSError *error = [NSError errorWithDomain:SOUNDBOARD_ERROR_DOMAIN
												 code:CANT_READ_PLIST
											 userInfo:plistRepresentation];
			*outError = error;
		}
		return NO;
	}
	return data;
}

#pragma mark Generic panel end handler

- (void)panelDidEnd:(NSPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[panel close];
}

#pragma mark Bindings accessors

//relative to (used by) the pop-up menu.
- (int)currentDeviceSelectionIndex {
	return lastSelectedDeviceIndex;
}
- (void)setCurrentDeviceSelectionIndex:(int)newIndex {
	[self willChangeValueForKey:@"currentDeviceSelectionIndex"];
	lastSelectedDeviceIndex = newIndex;
	[self  didChangeValueForKey:@"currentDeviceSelectionIndex"];

	//for undo.
	NSString *oldDeviceUID;
	if(undoEnabled)
		oldDeviceUID = [plistRepresentation objectForKey:LAST_DEVICE_KEY];

	//store it for next save.
	NSString *deviceUID = [[devicesPopUp selectedItem] representedObject];
	if(deviceUID)
		[plistRepresentation setObject:deviceUID forKey:LAST_DEVICE_KEY];
	else
		[plistRepresentation removeObjectForKey:LAST_DEVICE_KEY];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		deviceUID, SELECTED_DEVICE_UID,
		[AudioDevice deviceWithUID:deviceUID], SELECTED_DEVICE_AUDIODEVICE,
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:SELECTED_DEVICE_CHANGED_NOTIFICATION
														object:self
													  userInfo:userInfo];

	//undo, continued.
	if(undoEnabled) {
		NSNull *null = [NSNull null];
		NSDictionary *undoDesc = [NSDictionary dictionaryWithObjectsAndKeys:
			UNDO_DEVICECHANGED, UNDO_ACTIONNAME,
			oldDeviceUID ? oldDeviceUID : (NSString *)null, UNDO_OLDVALUE,
			   deviceUID ?    deviceUID : (NSString *)null, UNDO_NEWVALUE,
			nil];
		NSUndoManager *undoManager = [self undoManager];
		[undoManager registerUndoWithTarget:self
								   selector:@selector(performUndo:)
									 object:undoDesc];
		[undoManager setActionName:NSLocalizedString(UNDO_DEVICECHANGED, /*comment*/ nil)];
	}
}

- (float)volume {
	return volume;
}
- (void)setVolume:(float)newVol {
	float oldVolume = volume;

	[self willChangeValueForKey:@"volume"];
	volume = newVol;
	[self  didChangeValueForKey:@"volume"];

	//store it for next save.
	NSNumber *num = [NSNumber numberWithFloat:volume];
	[plistRepresentation setObject:num forKey:LAST_VOLUME_KEY];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		num, NEW_VOLUME,
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:VOLUME_CHANGED_NOTIFICATION
														object:self
													  userInfo:userInfo];

	if(undoEnabled) {
		NSUndoManager *undoManager = [self undoManager];
		[[undoManager prepareWithInvocationTarget:self] setVolume:oldVolume];
		[undoManager setActionName:NSLocalizedString(UNDO_VOLUMECHANGED, /*comment*/ nil)];
	}
}

#pragma mark NSWindow resizing

- (void)windowLiveResizeWillBegin:(NSNotification *)notification {
	NSWindow *window = [notification object];

	//we are resizing the matrix (cell-by-cell) if the option key is *not* down.
	//if it is down, we are resizing the cells, point-by-point for each one.
	resizingMatrix = !([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask);
	resizingCells =  !resizingMatrix;

	NSSize matrixDimensions = { [moviesMatrix numberOfColumns], [moviesMatrix numberOfRows] };

	cellSizeDuringResize = BZAddSizes([moviesMatrix cellSize], [moviesMatrix intercellSpacing]);

	if(resizingCells) {
		sizeBeforeResize = [window frame].size;

		[window setResizeIncrements:matrixDimensions];
	} else if(resizingMatrix) {
		sizeBeforeResize = matrixDimensions;

		[window setResizeIncrements:cellSizeDuringResize];
	}
}
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize {
	if(resizingMatrix) {
		NSSize existingFrameSize = [sender frame].size;

		NSSize sizeDelta = {
			floorf((proposedFrameSize.width  - existingFrameSize.width)  / cellSizeDuringResize.width),
			floorf((proposedFrameSize.height - existingFrameSize.height) / cellSizeDuringResize.height)
		};

		[self applySizeDeltaToMatrix:sizeDelta];
	}

	return proposedFrameSize;
}
- (void)windowLiveResizeDidEnd:(NSNotification *)notification {
	if(resizingMatrix || resizingCells) {
		NSWindow *window = [notification object];
		NSSize newSize = resizingMatrix
		               ? (NSSize){ [moviesMatrix numberOfColumns], [moviesMatrix numberOfRows] }
		               : [window frame].size;
		if(!NSEqualSizes(sizeBeforeResize, newSize)) {
			if(resizingCells) {
				sizeBeforeResize = cellSizeDuringResize;
				newSize = BZAddSizes([moviesMatrix cellSize], [moviesMatrix intercellSpacing]);
			}

//			[self updateChangeCount:NSChangeDone];
			NSUndoManager *undoManager = [self undoManager];

			NSString *actionName = resizingMatrix ? UNDO_MATRIXDIMENSIONSCHANGED : UNDO_CELLSIZECHANGED;
			NSDictionary *undoDesc = [NSDictionary dictionaryWithObjectsAndKeys:
				actionName, UNDO_ACTIONNAME,
				[NSValue valueWithSize:sizeBeforeResize], UNDO_OLDVALUE,
				[NSValue valueWithSize:newSize], UNDO_NEWVALUE,
				nil];
			[undoManager registerUndoWithTarget:self
									   selector:@selector(performUndo:)
										 object:undoDesc];
			[undoManager setActionName:NSLocalizedString(actionName, /*comment*/ nil)];
		}
	}
}

#pragma mark Matrix size

- (void)setMatrixSizeInPoints:(NSSize)newSize {
	//get the space that exists on all sides of the matrix, to add to the new size.
	NSRect windowFrame = [playerWindow frame];
	NSSize gutter = BZSubtractSizes(windowFrame.size, [moviesMatrix frame].size);

	newSize = BZAddSizes(newSize, gutter);
	windowFrame.origin.y -= (newSize.height - windowFrame.size.height);
	windowFrame.size = newSize;
	[playerWindow setFrame:windowFrame display:YES animate:YES];
}

#pragma mark KVO

//this is how we're notified that cell's movie has changed.
- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if(undoEnabled) {
		BZMovieButtonCell *cell = object;

		int row, col;
		[moviesMatrix getRow:&row column:&col ofCell:cell];

		NSDictionary *undoDesc = [NSDictionary dictionaryWithObjectsAndKeys:
			UNDO_CELLMOVIECHANGED, UNDO_ACTIONNAME,

			[change objectForKey:NSKeyValueChangeOldKey], UNDO_OLDVALUE,
			[change objectForKey:NSKeyValueChangeNewKey], UNDO_NEWVALUE,

			cell, UNDO_CELL,
			[NSNumber numberWithInt:row], UNDO_CELL_ROWINDEX,
			[NSNumber numberWithInt:col], UNDO_CELL_COLUMNINDEX,

			nil];

		NSUndoManager *undoManager = [self undoManager];
		[undoManager registerUndoWithTarget:self
								   selector:@selector(performUndo:)
									 object:undoDesc];
		[undoManager setActionName:NSLocalizedString(UNDO_CELLMOVIECHANGED, /*comment*/ nil)];
	}
}

#pragma mark Undo

- (void)performUndo:(NSDictionary *)undoDesc {
	NSString *actionName = [undoDesc objectForKey:UNDO_ACTIONNAME];

	//for redo
	NSMutableDictionary *newDesc = [undoDesc mutableCopy];
	[newDesc setObject:[undoDesc objectForKey:UNDO_OLDVALUE] forKey:UNDO_NEWVALUE];
	[newDesc setObject:[undoDesc objectForKey:UNDO_NEWVALUE] forKey:UNDO_OLDVALUE];

	if([actionName isEqualToString:UNDO_MATRIXDIMENSIONSCHANGED]) {
		NSSize oldSize = [[undoDesc objectForKey:UNDO_OLDVALUE] sizeValue];
		NSSize newSize = [[undoDesc objectForKey:UNDO_NEWVALUE] sizeValue];

		//add or remove columns/rows as needed.
		NSSize sizeDelta = BZSubtractSizes(oldSize, newSize);
		[self applySizeDeltaToMatrix:sizeDelta];

		NSSize intercellSpacing = [moviesMatrix intercellSpacing];
		NSSize cellSize = BZAddSizes([moviesMatrix cellSize], intercellSpacing);

		//multiply the size of a cell (including inter-cell spacing) by the dimensions of the matrix.
		//be sure to knock off one inter-cell spacing; not doing so is a fencepost error.
		NSSize matrixSize = BZSubtractSizes(BZMultiplySizes(cellSize, oldSize), intercellSpacing);

		[self setMatrixSizeInPoints:matrixSize];
	} else if([actionName isEqualToString:UNDO_CELLSIZECHANGED]) {
		NSSize matrixSize = BZSubtractSizes(BZMultiplySizes([[undoDesc objectForKey:UNDO_OLDVALUE] sizeValue], (NSSize){ [moviesMatrix numberOfColumns], [moviesMatrix numberOfRows] }), [moviesMatrix intercellSpacing]);

		[self setMatrixSizeInPoints:matrixSize];
	} else if([actionName isEqualToString:UNDO_CELLMOVIECHANGED]) {
		undoEnabled = NO;

		NSNumber *colNum = [undoDesc objectForKey:UNDO_CELL_COLUMNINDEX];
		NSNumber *rowNum = [undoDesc objectForKey:UNDO_CELL_ROWINDEX];

		BZMovieButtonCell *cell = [moviesMatrix cellAtRow:[rowNum intValue] column:[colNum intValue]];

		QTMovie *movie = [undoDesc objectForKey:UNDO_OLDVALUE];
		if(movie == (QTMovie *)[NSNull null])
			movie = nil;
		[cell setMovie:movie];

		undoEnabled = YES;
	} else if([actionName isEqualToString:UNDO_DEVICECHANGED]) {
		undoEnabled = NO;

		NSString *oldDeviceUID = [undoDesc objectForKey:UNDO_OLDVALUE];
		int idx = [devicesPopUp indexOfItemWithRepresentedObject:oldDeviceUID];
		if(idx < 0)
			idx = 0;
		[self setCurrentDeviceSelectionIndex:idx];

		undoEnabled = YES;
	} else {
	}

	[[self undoManager] registerUndoWithTarget:self
									  selector:@selector(performUndo:)
										object:newDesc];
	[newDesc release];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender {
	return [self undoManager];
}

#pragma mark End of implementation
@end

@implementation SBDocument (PRIVATE)

- (void)fillOutDevicesPopUp {
	OSStatus err;
	UInt32 size;

	err = AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &size, /*outWritable*/ NULL);

	if(err != noErr) {
		NSPanel *alert = NSGetAlertPanel(@"Could not get size of audio devices array", @"When trying to get the size of the array of audio output devices, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
		[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	} else {

		AudioDeviceID *deviceIDs = malloc(size);

		if(!deviceIDs) {
			NSPanel *alert = NSGetAlertPanel(@"Could not allocate audio devices array", @"When trying to get memory for the array of audio output devices, an error of type %i occurred: %s", @"OK", nil, nil, errno, strerror(errno));
			[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
		} else {

			err = AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &size, deviceIDs);

			if(err != noErr) {
				NSPanel *alert = NSGetAlertPanel(@"Could not get audio devices array", @"When trying to get the the array of audio output devices, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
				[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
			} else {
				UInt32 numDevices = size / sizeof(AudioDeviceID);
				for(UInt32 deviceIdx = 0U; deviceIdx < numDevices; ++deviceIdx) {
					NSString *UID;
					size = sizeof(UID);

					err = AudioDeviceGetProperty(deviceIDs[deviceIdx], /*inChannel*/ 0U, /*isInput*/ false, kAudioDevicePropertyDeviceUID, &size, &UID);

					if(err != noErr) {
						NSPanel *alert = NSGetAlertPanel(@"Could not get audio device UID", @"When trying to get the UID (unique identifier) of an audio output device, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
						[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
					} else {
						NSString *name;
						size = sizeof(name);

						err = AudioDeviceGetProperty(deviceIDs[deviceIdx], /*inChannel*/ 0U, /*isInput*/ false, kAudioObjectPropertyName, &size, &name);

						if(err != noErr) {
							NSPanel *alert = NSGetAlertPanel(@"Could not get audio device name", @"When trying to get the name of an audio output device (with UID %@), an error of type %i (%s) occurred: %s", @"OK", nil, nil, UID, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
							[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
						} else {
							[devicesPopUp addItemWithTitle:name];
							NSMenuItem *menuItem = [devicesPopUp lastItem];
							[menuItem setRepresentedObject:UID];

							//CoreAudio gives us an implicitly-retained CFString.
							[name release];
						} //if(err == noErr) (AudioDeviceGetProperty(...kAudioObjectPropertyObjectName...))

						//CoreAudio gives us an implicitly-retained CFString.
						[UID release];
					} //if(err == noErr) (AudioDeviceGetProperty(...kAudioDevicePropertyDeviceUID...))
				} //for(UInt32 deviceIdx = 0U; deviceIdx < numDevices; ++deviceIdx)
			} //if(err == noErr) (AudioHardwareGetProperty(kAudioHardwarePropertyDevices...))
		} //if(deviceIDs)
	} //if(err == noErr) (AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices...))
}

#pragma mark Movie-making

- (QTMovie *)movieAtRow:(unsigned)rowIdx column:(unsigned)colIdx {
	QTMovie *movie = nil;

	NSArray *rowsInPlist = [plistRepresentation objectForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	if(rowIdx < [rowsInPlist count]) {

		NSArray *row = [rowsInPlist objectAtIndex:rowIdx];
		if(colIdx < [row count]) {

			NSObject *obj = [row objectAtIndex:colIdx];
			if(![obj isEqual:EMPTY_CELL]) {

				NSDictionary *desc = (NSDictionary *)obj;
				NSString *path = [[NSURL fileURLWithDockDescription:desc] path];
		
				NSError *error = nil;
				movie = [[QTMovie alloc] initWithFile:path error:&error];
				if(error) {
					NSPanel *alert = NSGetAlertPanel(@"Could not open file", @"The file %@ could not be opened because: %@", @"OK", nil, nil, path, [error localizedFailureReason]);
					[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL]; 
				}

				if(movie) {
					movie = [movie autorelease];

					[movie setVolume:volume];
					NSString *deviceUID = [[devicesPopUp selectedItem] representedObject];
					if(deviceUID)
						[movie setAudioDevice:[AudioDevice deviceWithUID:deviceUID]];
				}
			}
		}
	}

	return movie;
}

#pragma mark There is no spoon

- (void)addColumnsToMatrix:(unsigned)numCols {
	unsigned firstNewColumnIndex = [moviesMatrix numberOfColumns];
	unsigned numRowsInMatrix = [moviesMatrix numberOfRows];
	unsigned numRows = numRowsInMatrix;

	for(register unsigned i = numCols; i; i--)
		[moviesMatrix addColumn];
	numCols += firstNewColumnIndex; //now it's the number of columns in the matrix (== [moviesMatrix numberOfColumns]). this changed since the -addColumn calls.

	NSArray *rowsInPlist = [plistRepresentation objectForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	unsigned rowsInPlistCount = [rowsInPlist count];
	if(rowsInPlistCount < numRows)
		numRows = rowsInPlistCount;

	for(register unsigned y = 0U; y < numRows; ++y) {
		NSArray *row = [rowsInPlist objectAtIndex:y];
		if([row count] <= firstNewColumnIndex)
			/*pass*/;
		else {
			unsigned numColsThisRow = [row count];
			numColsThisRow = MIN(numCols, numColsThisRow);
			for(register unsigned x = 0U; x < numColsThisRow; ++x) {
				NSObject *obj = [row objectAtIndex:x];
				if(![obj isEqual:EMPTY_CELL]) {
					BZMovieButtonCell *cell = [moviesMatrix cellAtRow:y column:x];

					//there is a Dock description here; make a movie for this cell.
					//volume and device must be set here so that the cell knows about them in case its movie is changed (by drag-and-drop).
					[cell setMovie:[self movieAtRow:y column:x]];
					[cell setVolume:volume];
					NSString *deviceUID = [[devicesPopUp selectedItem] representedObject];
					if(deviceUID)
						[cell setAudioDevice:[AudioDevice deviceWithUID:deviceUID]];
				}
			}
		}
	}

	for(register unsigned x = firstNewColumnIndex; x < numCols; ++x) {
		for(register unsigned y = 0U; y < numRowsInMatrix; ++y) {
			BZMovieButtonCell *cell = [moviesMatrix cellAtRow:y column:x];

			[cell addObserver:self
				   forKeyPath:@"movie"
					  options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					  context:NULL];
		}
	}
}
- (void)addRowsToMatrix:(unsigned)numRows {
	unsigned firstNewRowIndex = [moviesMatrix numberOfRows];
	unsigned numCols = [moviesMatrix numberOfColumns];

	for(register unsigned i = numRows; i; i--)
		[moviesMatrix addRow];
	unsigned numRowsInMatrix = firstNewRowIndex + numRows;

	NSArray *rowsInPlist = [plistRepresentation objectForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	unsigned rowsInPlistCount = [rowsInPlist count];
	if(firstNewRowIndex < rowsInPlistCount) {
		numRows += firstNewRowIndex; //now it's the number of rows in the matrix (== [moviesMatrix numberOfRows]). this changed since the -addRow calls.
		if(numRows > rowsInPlistCount)
			numRows = rowsInPlistCount;

		for(register unsigned y = firstNewRowIndex; y < numRows; ++y) {
			NSArray *row = [rowsInPlist objectAtIndex:y];

			//note: MIN evaluates each expression twice, hence the assignment-then-MIN.
			unsigned numColsThisRow = [row count];
			numColsThisRow = MIN(numCols, numColsThisRow);

			for(register unsigned x = 0U; x < numColsThisRow; ++x) {
				NSObject *obj = [row objectAtIndex:x];
				if(![obj isEqual:EMPTY_CELL]) {
					//there is a Dock description here; make a movie for this cell.
					//volume and device must be set here so that the cell knows about them in case its movie is changed (by drag-and-drop).
					BZMovieButtonCell *cell = [moviesMatrix cellAtRow:y column:x];
					[cell setMovie:[self movieAtRow:y column:x]];
					[cell setVolume:volume];
					NSString *deviceUID = [[devicesPopUp selectedItem] representedObject];
					if(deviceUID)
						[cell setAudioDevice:[AudioDevice deviceWithUID:deviceUID]];
				}
			}
		}
	}

	for(register unsigned y = firstNewRowIndex; y < numRowsInMatrix; ++y) {
		for(register unsigned x = 0U; x < numCols; ++x) {
			BZMovieButtonCell *cell = [moviesMatrix cellAtRow:y column:x];

			[cell addObserver:self
				   forKeyPath:@"movie"
					  options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					  context:NULL];
		}
	}
}

- (void)removeColumnsFromMatrix:(unsigned)numCols {
	int idx = [moviesMatrix numberOfColumns] - numCols;
	for(unsigned i = numCols; i; --i) {
		NSArray *col = [moviesMatrix columnAtIndex:idx];
		NSEnumerator *colEnum = [col objectEnumerator];
		BZMovieButtonCell *cell;
		while((cell = [colEnum nextObject])) {
			[cell removeObserver:self forKeyPath:@"movie"];
		}

		//now take the column out of the matrix.
		[moviesMatrix removeColumn:idx];
	}
}
- (void)removeRowsFromMatrix:(unsigned)numRows {
	int idx = [moviesMatrix numberOfRows] - numRows;
	for(unsigned i = numRows; i; --i) {
		//first, stop observing for changes to the cells' movies.
		NSArray *row = [moviesMatrix rowAtIndex:idx];
		NSEnumerator *rowEnum = [row objectEnumerator];
		BZMovieButtonCell *cell;
		while((cell = [rowEnum nextObject]))
			[cell removeObserver:self forKeyPath:@"movie"];

		//now take the row out of the matrix.
		[moviesMatrix removeRow:idx];
	}
}

- (void)applySizeDeltaToMatrix:(NSSize)sizeDelta {
	int num = [moviesMatrix numberOfRows];
	if(signbit(sizeDelta.height)) {
		//negative - subtract rows
		[self removeRowsFromMatrix:-sizeDelta.height];
	} else {
		//zero or positive - add rows
		[self addRowsToMatrix:sizeDelta.height];
	}
	
	num = [moviesMatrix numberOfColumns];
	if(signbit(sizeDelta.width)) {
		//negative - subtract columns
		[self removeColumnsFromMatrix:-sizeDelta.width];
	} else {
		//zero or positive - add columns
		[self addColumnsToMatrix:sizeDelta.width];
	}
}

@end
