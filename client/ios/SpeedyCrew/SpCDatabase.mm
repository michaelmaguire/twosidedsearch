//
//  SpCDatabase.mm
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 04/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCDatabase.h"
#include "Database.h"
// #import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <string>
#include <sqlite3.h>

static sqlite3*     database_ = 0;
static SpCDatabase* object = nil;
static SpeedyCrew::Database s_database;

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int ignore_callback(void* ud,int count,char** a0, char** a1)
    {
        return 0;
    }
}

// ----------------------------------------------------------------------------

@implementation SpCDatabase

- (id)init {
    if ((self = [super init])) {
        try {
            NSFileManager* manager = [NSFileManager new];
            NSError* error = nil;
            NSURL* support = [manager URLForDirectory:NSApplicationSupportDirectory
                                             inDomain:NSUserDomainMask appropriateForURL:nil
                                               create:YES error:&error];
            std::string name([[support absoluteString] UTF8String]);
            name += "crew.sqlite3";
            NSLog(@"using database '%s'", name.c_str());
            s_database.initialize(name);
            
            NSLog(@"setting up database tables");
            s_database.createTable("settings", "name TEXT PRIMARY KEY, value TEXT");
            s_database.createTable("searches",
                                   "id TEXT PRIMARY KEY, side TEXT, search TEXT");
            
#if 0
            std::string uuidstr("1234"); //-dk:TODO ([[[UIDevice currentDevice].identifierForVendor UUIDString] UTF8String]);
            NSLog(@"uuid='%s'", uuidstr.c_str());
            std::string idsql("insert into settings (name, value) values('scid', '" + uuidstr + "');");
            message msg;;
            int rc(sqlite3_exec(database_, idsql.c_str(), ignore_callback, 0, &msg));
            // NSLog(@"insert into settings database: %s", idsql.c_str());
#endif
        }
        catch (std::exception const& ex) {
            NSLog(@"ERROR: %s", ex.what());
        }
    }
    return self;
}

+ (SpeedyCrew::Database*) getDatabase
{
    [SpCDatabase database];
    return &s_database;
}

- (void)dealloc {
    sqlite3_close(database_);
    // [super dealloc];
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
    NSString* insert = [NSString stringWithFormat:@"insert into settings (name, value) values('%@', '%%q');", name];
    char* message = 0;
    char buffer[512];
    char* sql = sqlite3_snprintf(sizeof(buffer), buffer, [insert UTF8String], [value UTF8String]);
    if (sqlite3_exec(database_, sql, ignore_callback, 0, &message)) {
        NSString* update = [NSString stringWithFormat:@"update settings set value='%%q' where name='%@';", name];
        sql = sqlite3_snprintf(sizeof(buffer), buffer, [update UTF8String], [value UTF8String]);
        if (sqlite3_exec(database_, sql, ignore_callback, 0, &message)) {
            NSLog(@"both update and insert failed for setting name='%@' value='%@' message='%s'", name, value, message);
        }
    }
}

// ----------------------------------------------------------------------------

- (void) addSearch:(NSString*)search forSide:(NSString*)side withId:(NSString*) id
{
    try {
        s_database.execute("INSERT INTO searches (id, side, search) "
                         "VALUES("
                         "'" + s_database.escape([id UTF8String]) + "', "
                         "'" + s_database.escape([side UTF8String]) + "', "
                         "'" + s_database.escape([search UTF8String]) + "')");
    }
    catch (std::exception const& ex) {
        NSLog(@"inserting search failed: %s", ex.what());
    }
}

- (void) removeSearch:(NSString*)id
{
    try {
        s_database.execute("DELETE FROM searches WHERE "
                         "id='" + s_database.escape([id UTF8String]) + "'");
        //-dk:TODO remove responses
    }
    catch (std::exception const& ex) {
        NSLog(@"deleting search failed: %s", ex.what());
    }
}

- (int)numberSearchesFor:(NSString*)side
{
    return s_database.query<int>("SELECT COUNT(*) FROM searches where "
                               "side='" + s_database.escape([side UTF8String]) + "'");
}

// ----------------------------------------------------------------------------

- (int) queryVector:(NSString*)query
{
    std::vector<std::string> value(s_database.queryVector([query UTF8String]));
    std::string result("[");
    if (!value.empty()) {
        result += value.front();
        for (std::vector<std::string>::const_iterator it(value.begin() + 1), end(value.end()); it != end; ++it) {
            result += ", " + *it;
        }
    }
    result += "]";
    NSLog(@"queryVector(%@)->%s", query, result.c_str());
    return 0;
}
@end
