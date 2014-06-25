//
//  Database.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 05/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#ifndef SpeedyCrew_Database
#define SpeedyCrew_Database


#include <string>
#include <utility>
#include <vector>
#include <sqlite3.h>

// ----------------------------------------------------------------------------

namespace SpeedyCrew
{
    class Database;
}

// ----------------------------------------------------------------------------

class SpeedyCrew::Database
{
    sqlite3* d_database;

    Database(Database&);
    void operator= (Database&);
 public:
    class Transaction
    {
        Transaction(Transaction&);
        void operator=(Transaction);
        SpeedyCrew::Database* m_db;
    public:
        Transaction(SpeedyCrew::Database& db);
        Transaction(SpeedyCrew::Database* db);
        ~Transaction();
        void commit();
    };

    static std::string escape(std::string const& argument);
    static std::string escape(char const* argument);

    Database();
    ~Database();
    void initialize(std::string const& path);

    void createTable(std::string const& table, std::string const& columns);
    void execute(std::string const& sql);
    bool execute(std::string const& sql, std::string& error);

    template <typename T> T  query(std::string const& sql);
    std::vector<std::string> queryRow(std::string const& sql);
    std::vector<std::string> queryColumn(std::string const& sql);
};

// ----------------------------------------------------------------------------

#endif /* defined(SpeedyCrew_Database) */
