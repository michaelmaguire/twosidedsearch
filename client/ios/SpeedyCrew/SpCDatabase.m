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

int ignore_callback(void* ud,int count,char** a0, char** a1)
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
    NSLog(@"settings query: '%@'", query);
    if (sqlite3_prepare_v2(database_, [query UTF8String], -1, &statement, nil) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            NSLog(@"received a result: '%s'", (char*)sqlite3_column_text(statement, 0));
            result = [NSString stringWithUTF8String:((char *) sqlite3_column_text(statement, 0))];
            break;
        }
        sqlite3_finalize(statement);
    }
    return result;
}

- (NSString*) querySetting: (NSString*)id withDefault:(NSString*)def
{
    //-dk:TODO
    return @"TODO";
}

@end
