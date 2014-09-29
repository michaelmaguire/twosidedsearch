//
//  SpCUserViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 04/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCUserViewController.h"
#import "SpCDatabase.h"
#import "SpCAppDelegate.h"
#import "SpCData.h"
#include "Database.h"
#include <string>

@interface SpCUserViewController ()
@property NSArray* elements;

@end

@implementation SpCUserViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.elements = @[@"scid", @"real_name", @"username", @"email", @"message"];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)path
{
    NSString* id = [self.elements objectAtIndex:path.row];
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:id forIndexPath:path];
    std::string scid(db->query<std::string>("select value from settings where name='scid'"));
    if (0 == (long)path.row) {
        NSString* value = [NSString stringWithFormat:@"%s", scid.c_str()];
        UIView* view = [cell.contentView viewWithTag:1];
        if (view && ![view isEqual:[NSNull null]]) {
            UILabel* label = (UILabel*)view;
            label.text = value;
        }
    }
    else {
        UIView* view = [cell.contentView viewWithTag: -1];
        if (view && ![view isEqual:[NSNull null]]) {
            std::string val;
            if (db->query<int>("select count(*) from profile where fingerprint='" + scid + "'") == 1) {
                val = db->query<std::string>("select " + std::string([id UTF8String]) + " from profile where fingerprint='" + scid + "'");
            }
            NSString* value = [NSString stringWithFormat:@"%s", val.c_str()];
            UITextField* text = (UITextField*)view;
            text.text     = value;
            text.tag      = path.row;
            text.delegate = self;
        }
        else {
            NSLog(@"couldn't locate content view for row '%ld' name='%@'", (long)path.row, id);
        }
    }
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    [delegate.data updateSetting:self.elements[textField.tag] with:textField.text];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
