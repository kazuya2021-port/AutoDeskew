//
//  AppDelegate.m
//  AutoDeskew
//
//  Created by uchiyama_Macmini on 2019/05/28.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#import "RecognizeDegree.h"
#import <KZLibs.h>
#import <KZImage/KZImage.h>
#import <KZImage/ImageEnum.h>
#import "AppDelegate.h"
#import <Foundation/Foundation.h>

@interface AppDelegate () <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSControlTextEditingDelegate>
@property (nonatomic, weak) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet NSTableView *table;
@property (nonatomic, retain) NSMutableArray* tableData;
@property (nonatomic, retain) RecognizeDegree* degTool;
@property (nonatomic, weak) IBOutlet NSTextField *trimHeight;
@property (nonatomic, weak) IBOutlet NSTextField *trimBottom;
@property (nonatomic, weak) IBOutlet NSTextField *trimRight;
@property (nonatomic, weak) IBOutlet NSTextField *trimLeft;
@property (nonatomic, weak) IBOutlet NSTextField *hanRL;
@property (nonatomic, weak) IBOutlet NSTextField *hanBottom;
@property (nonatomic, weak) IBOutlet NSTextField *saveFol;
@property (nonatomic, weak) IBOutlet NSTextField *saveDpi;
@property (nonatomic, weak) IBOutlet NSTextField *dustArea;
@property (nonatomic, retain) KZImage *imgUtil;

- (IBAction)getDegree:(id)sender;
- (IBAction)clearTable:(id)sender;
@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _tableData = [NSMutableArray array];
    NSSortDescriptor *descriptorf = [[NSSortDescriptor alloc] initWithKey:@"filename" ascending:YES selector:@selector(compare:)];
    NSSortDescriptor *descriptord = [[NSSortDescriptor alloc] initWithKey:@"degree" ascending:YES selector:@selector(compare:)];
    [_table registerForDraggedTypes:@[NSFilenamesPboardType]];
    _table.target = self;
    _table.delegate = self;
    _table.dataSource = self;
    _table.sortDescriptors = @[descriptorf,descriptord];
    _degTool = [[RecognizeDegree alloc] init];
    _degTool.beforeDegree = 0;
    _imgUtil = [[KZImage alloc] init];
    [_imgUtil startEngine];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
     [_imgUtil stopEngine];
}

- (IBAction)clearTable:(id)sender
{
    [_tableData removeAllObjects];
    [_table reloadData];
}

- (IBAction)getDegree:(id)sender
{
    _degTool.hanRL = _hanRL.doubleValue;
    _degTool.hanB = _hanBottom.doubleValue;
    _degTool.dustArea = _dustArea.doubleValue;
    
    NSOperationQueue *aQ = [[NSOperationQueue alloc] init];
    double trH = _trimHeight.doubleValue;
    double trR = _trimRight.doubleValue;
    double trL = _trimLeft.doubleValue;
    double trB = _trimBottom.doubleValue;
    
    NSString *saveCur = _saveFol.stringValue;
    ConvertSetting *saveSetting = [[ConvertSetting alloc] init];
    
    saveSetting.Resolution = _saveDpi.doubleValue;
    saveSetting.isResize = NO;
    saveSetting.toSpace = KZColorSpace::GRAY;
    
    NSOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        for (NSMutableDictionary* d in _tableData) {
            @autoreleasepool {
                NSString *name = [d[@"filepath"] lastPathComponent];
                [_degTool openImage:d[@"filepath"]];
                [_degTool cropImg:trH right:trR left:trL bottom:trB];
                double deg = [_degTool getDegree];
                [_degTool rotate:deg];
                d[@"degree"] = [NSNumber numberWithDouble:deg];
                int ngCount = 0;
                while (true) {
                    if (ngCount == 1) {
                        break;
                    }
                    deg = [_degTool getDegree];
                    if (deg != 0) {
                        [_degTool rotate:deg];
                    }
                    else {
                        break;
                    }
                    ngCount++;
                }
                
                NSData *retImg = [_degTool saveImage:name];
                
                [_imgUtil ImageConvertfromBuffer:retImg
                                              to:saveCur
                                          format:KZFileFormat::TIFF_FORMAT
                                    saveFileName:[name stringByDeletingPathExtension]
                                         setting:saveSetting];
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [_table reloadData];
                });
            }
        }
    }];
    
    aQ.maxConcurrentOperationCount = 4;
    [aQ addOperation:op];
}

#pragma mark -
#pragma mark DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _tableData.count;
}

/*- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
 {
 NSData *indexSetWithData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
 NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
 [item setData:indexSetWithData forType:NSTableRowType];
 [pboard writeObjects:@[item]];
 return YES;
 }*/

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    if (row > _tableData.count || row < 0) {
        return NSDragOperationNone;
    }
    
    if (!info.draggingSource) {
        return NSDragOperationCopy;
    }
    else if (info.draggingSource == self) {
        return NSDragOperationNone;
    }
    else if (info.draggingSource == tableView) {
        [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
        return NSDragOperationMove;
    }
    return NSDragOperationCopy;
}

- (NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *data = _tableData[row];
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    
    cell.objectValue = data[identifier];
    cell.textField.stringValue = data[identifier];
    cell.identifier = [identifier stringByAppendingString:[NSString stringWithFormat:@"%ld", (long)row]];
    cell.textField.delegate = self;
    cell.textField.cell.representedObject = @{@"Col" : identifier,
                                              @"Row" : [NSNumber numberWithInteger:row]};
    return cell;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    NSTableView *dragSource = info.draggingSource;
    if (dragSource != NULL) {
        if (NEQ_STR(dragSource.identifier, tableView.identifier)) {
            return NO;
        }
    }
    
    NSPasteboard *pb = info.draggingPasteboard;
    NSArray *arTypes = pb.types;
    
    for (NSString *type in arTypes) {
        if (EQ_STR(type,NSFilenamesPboardType)) {
            // File Drop To Table View
            NSData *data = [pb dataForType:NSFilenamesPboardType];
            NSError *error;
            NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
            NSArray *theFiles = [NSPropertyListSerialization
                                 propertyListWithData:data
                                 options:(NSPropertyListReadOptions)NSPropertyListImmutable
                                 format:&format
                                 error:&error];
            if (error) {
                LogF(@"get file property error : %@", error.description);
                break;
            }
            if (!theFiles) {
                Log(@"get file property error");
                break;
            }
            
            for (NSUInteger i = 0; i < theFiles.count; i++) {
                NSMutableDictionary *muRow = [@{} mutableCopy];
                [muRow setObject:[KZLibs getFileName:theFiles[i]] forKey:@"filename"];
                [muRow setObject:theFiles[i] forKey:@"filepath"];
                [muRow setObject:@0 forKey:@"degree"];
                _tableData[i] = muRow;
                //LogF(@"%@",muRow);
            }
            
            [tableView reloadData];
        }
    }
    return YES;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors
{
    [_tableData sortUsingDescriptors:[tableView sortDescriptors]];
    [tableView reloadData];
}

#pragma mark -
#pragma mark Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField* field = (NSTextField*)obj.object;
    NSString *fieldString = field.stringValue.precomposedStringWithCanonicalMapping;
    field.stringValue = fieldString;
    if (field.cell.representedObject) {
        // for use Table View Edit
    }
}

@end
