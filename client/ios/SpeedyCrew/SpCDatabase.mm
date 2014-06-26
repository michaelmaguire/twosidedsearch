//
//  SpCDatabase.mm
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 04/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCDatabase.h"
#include "Database.h"
#import <UIKit/UIKit.h>
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
            s_database.initialize(name);
            
            NSLog(@"setting up database tables");
            s_database.createTable("settings", "name TEXT PRIMARY KEY, value TEXT"); //-dk:TODO remove
            s_database.createTable("expanded", "id TEXT PRIMARY KEY, state INTEGER"); //-dk:TODO remove
            
            try {
                std::string uuidstr([[[UIDevice currentDevice].identifierForVendor UUIDString] UTF8String]);
                NSLog(@"using database='%s' uuid='%s'", name.c_str(), uuidstr.c_str());
                s_database.execute("insert into settings (name, value) values('scid', '" + uuidstr + "');");
            }
            catch (std::exception const& ex) {
                NSLog(@"ERROR inserting UUID: %s", ex.what());
            }
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
    std::string query("select value from settings where name = '"
                      + s_database.escape([name UTF8String]) + "';");
    std::string result(s_database.query<std::string>(query));
    return [NSString stringWithFormat:@"%s", result.c_str()];
}

- (void) updateSetting:(NSString*)name with:(NSString*)value
{
    std::string error;
    if (!s_database.execute("insert into settings(name, value) values("
                            "'" + s_database.escape([name UTF8String]) + "', "
                            "'" + s_database.escape([value UTF8String]) + "'"
                            ");", error)
        && !s_database.execute("update settings set "
                               "value='" + s_database.escape([value UTF8String]) + "' "
                               "where name='" + s_database.escape([name UTF8String]) + "';", error)) {
        NSLog(@"both update and insert failed for setting name='%@' value='%@' message='%s'", name, value, error.c_str());
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
    std::vector<std::string> value(s_database.queryRow([query UTF8String]));
    std::string result("[");
    if (!value.empty()) {
        result += value.front();
        for (std::vector<std::string>::const_iterator it(value.begin() + 1), end(value.end()); it != end; ++it) {
            result += ", " + *it;
        }
    }
    result += "]";
    return 0;
}
@end
