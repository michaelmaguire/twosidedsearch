//
//  SpCDatabase.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 04/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCDatabase.h"
#import <UIKit/UIKit.h>
#include <sqlite3.h>

static sqlite3*     database_ = 0;
static SpCDatabase* object = nil;

static int ignore_callback(void* ud,int count,char** a0, char** a1)
{
    return 0;
}

@implementation SpCDatabase

- (id)init {
    if ((self = [super init])) {
        NSFileManager* manager = [NSFileManager new];
        NSError* error = nil;
        NSURL* support = [manager URLForDirectory:NSApplicationSupportDirectory
                              inDomain:NSUserDomainMask appropriateForURL:nil
                              create:YES error:&error];
        NSString* dir = [support absoluteString];
        NSString* name = [NSString stringWithFormat:@"%@crew.sqlite3", dir];
        if (sqlite3_open([name UTF8String], &database_) != SQLITE_OK) {
            NSLog(@"Failed to open database '%@'!", name);
        }
        else {
            NSLog(@"opened database '%@'", name);
            char* message = 0;
            const char* create_values = "CREATE TABLE settings(name TEXT PRIMARY KEY, "
                                                              "value TEXT );";
            int rc = sqlite3_exec(database_, create_values, ignore_callback, 0, &message);
            NSUUID* uuid = [UIDevice currentDevice].identifierForVendor;
            NSString* uuidstr = [uuid UUIDString];
            NSString* idsql = [NSString stringWithFormat:@"insert into settings (name, value) values('scid', '%@');", uuidstr];
            rc = sqlite3_exec(database_, [idsql UTF8String], ignore_callback, 0, &message);
            NSLog(@"insert id rc=%d message=%s id=%@", rc, message? message: "<nil>", idsql);
        }
    }
    return self;
}

- (void)dealloc {
    sqlite3_close(database_);
}

+ (SpCDatabase*) database {
    if (nil == object) {
        object = [[SpCDatabase alloc] init];
    }
    return object;
}

- (NSString*) querySetting: (NSString*)name
{
    NSString* query = [NSString stringWithFormat:@"select value from settings where name = '%@';", name];
    sqlite3_stmt *statement;
    NSString* result = @"";
    if (sqlite3_prepare_v2(database_, [query UTF8String], -1, &statement, nil) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            result = [NSString stringWithUTF8String:((char *) sqlite3_column_text(statement, 0))];
            break;
        }
        sqlite3_finalize(statement);
    }
    return result;
}

- (void) updateSetting:(NSString*)name with:(NSString*)value
{
    NSLog(@"updateSetting:%@ with:%@", name, value);
    NSString* insert = [NSString stringWithFormat:@"insert into settings (name, value) values('%@', '%@');", name, value];
    char* message = 0;
    if (sqlite3_exec(database_, [insert UTF8String], ignore_callback, 0, &message)) {
        NSString* update = [NSString stringWithFormat:@"update settings set value='%@' where name='%@';", value, name];
        if (sqlite3_exec(database_, [update UTF8String], ignore_callback, 0, &message)) {
            NSLog(@"both update and insert failed for setting name='%@' value='%@' message='%s'", name, value, message);
        }
    }
}

@end
