//
//  Database.cpp
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 05/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#include "Database.h"
#include <iostream>
#include <stdexcept>

// ----------------------------------------------------------------------------

namespace
{
    class message
    {
        char* d_message;
        message(message const&);
        void operator=(message const&);
    public:
        message(): d_message() {};
        ~message() {
            if (this->d_message) {
                sqlite3_free(this->d_message);
            }
        }
        operator void const*() const { return this->d_message; }

        std::string str() const { return this->d_message; }
        char const* c_str() const { return this->d_message; }
        char**      operator&() { return &this->d_message; }
    };
}

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int ignoreCallback(void* ud,int count,char** a0, char** a1)
    {
        return 0;
    }
}

// ----------------------------------------------------------------------------

std::string SpeedyCrew::Database::escape(char const* value)
{
    char buffer[512];
    return sqlite3_snprintf(sizeof(buffer), buffer, "%q", value);
}

std::string SpeedyCrew::Database::escape(std::string const& value)
{
    return SpeedyCrew::Database::escape(value.c_str());
}

// ----------------------------------------------------------------------------

SpeedyCrew::Database::Database()
    : d_database()
{
}

SpeedyCrew::Database::~Database()
{
    if (this->d_database) {
        sqlite3_close(this->d_database);
    }
}

void SpeedyCrew::Database::initialize(std::string const& path)
{
    if (sqlite3_open(path.c_str(), &this->d_database) != SQLITE_OK) {
        throw std::runtime_error("failed to open database '" + path + "'");
    }
}

// ----------------------------------------------------------------------------

void SpeedyCrew::Database::createTable(std::string const& table,
                                       std::string const& columns)
{
    std::string sql(std::string("CREATE TABLE ") + table + "(" + columns + ")");
    message     msg;
    int         rc(sqlite3_exec(this->d_database, sql.c_str(), ignoreCallback, 0, &msg));
    if (rc && msg && msg.str() != "table " + table + " already exists") {
        throw std::runtime_error("query='" + sql +"' message='" + msg.str() + "'");
    }
}

// ----------------------------------------------------------------------------

void SpeedyCrew::Database::execute(std::string const& sql)
{
    message msg;
    int     rc(sqlite3_exec(this->d_database, sql.c_str(), ignoreCallback, 0, &msg));
    if (rc && msg) {
        throw std::runtime_error("query='" + sql +"' message='" + msg.str() + "'");
    }
}

bool SpeedyCrew::Database::execute(std::string const& sql, std::string& error)
{
    message msg;
    int     rc(sqlite3_exec(this->d_database, sql.c_str(), ignoreCallback, 0, &msg));
    if (rc && msg) {
        error = msg.str();
    }
    return !rc;
}

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int int_callback(void* data, int count, char** rows,char**)
    {
        if (count == 1 && rows) {
            *static_cast<int*>(data) = atoi(rows[0]);
            return 0;
        }
        return 1;
    }
}
    
namespace SpeedyCrew
{
    template <>
    int Database::query<int>(std::string const& sql)
    {
        message msg;
        int value = 0;
        int rc(sqlite3_exec(this->d_database, sql.c_str(), int_callback, &value, &msg));
        if (rc != SQLITE_OK) {
            throw std::runtime_error("query failed: "
                                     "query='" + sql + "' "
                                     "message='" + msg.str() + "'");
        }
        return value;
    }

    template <>
    int Database::query<int>(std::string const& sql, int const& def)
    {
        message msg;
        int value = def;
        int rc(sqlite3_exec(this->d_database, sql.c_str(), int_callback, &value, &msg));
        return rc != SQLITE_OK? def: value;
    }
}

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int double_callback(void* data, int count, char** rows,char**)
    {
        if (count == 1 && rows) {
            *static_cast<double*>(data) = atof(rows[0]);
            return 0;
        }
        return 1;
    }
}
    
namespace SpeedyCrew
{
    template <>
    double Database::query<double>(std::string const& sql)
    {
        message msg;
        double value = 0;
        int rc(sqlite3_exec(this->d_database, sql.c_str(), double_callback, &value, &msg));
        if (rc != SQLITE_OK) {
            throw std::runtime_error("query failed: "
                                     "query='" + sql + "' "
                                     "message='" + msg.str() + "'");
        }
        return value;
    }
}

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int string_callback(void* data, int count, char** rows,char**)
    {
        if (count == 1 && rows) {
            *static_cast<std::string*>(data) = rows[0]? rows[0]: "";
            return 0;
        }
        return 1;
    }
}
    
namespace SpeedyCrew
{
    template <>
    std::string Database::query<std::string>(std::string const& sql)
    {
        message msg;
        std::string value;
        int rc(sqlite3_exec(this->d_database, sql.c_str(), string_callback, &value, &msg));
        if (rc != SQLITE_OK) {
            throw std::runtime_error("query failed: "
                                     "query='" + sql + "' "
                                     "message='" + msg.str() + "'");
        }
        return value;
    }
}

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int row_callback(void* data, int count, char** rows,char**)
    {
        if (rows) {
            std::vector<std::string>* vec = static_cast<std::vector<std::string>*>(data);
            for (int i(0); i != count; ++i) {
                vec->push_back(rows[i]);
            }
            return 0;
        }
        return 1;
    }
}
    
namespace SpeedyCrew
{
    std::vector<std::string> Database::queryRow(std::string const& sql)
    {
        message msg;
        std::vector<std::string> value;
        int rc(sqlite3_exec(this->d_database, sql.c_str(), row_callback, &value, &msg));
        if (rc != SQLITE_OK) {
            throw std::runtime_error("query failed: "
                                     "query='" + sql + "' "
                                     "message='" + msg.str() + "'");
        }
        return value;
    }
}

// ----------------------------------------------------------------------------

namespace
{
    extern "C" int column_callback(void* data, int count, char** rows,char**)
    {
        if (count != 1) {
            std::cout << "WARNING: row with " << count << "columns in query for 1 column\n" << std::flush;
        }
        if (rows) {
            std::vector<std::string>* vec = static_cast<std::vector<std::string>*>(data);
            vec->push_back(rows[0]? rows[0]: std::string());
            return 0;
        }
        return 1;
    }
}
    
namespace SpeedyCrew
{
    std::vector<std::string> Database::queryColumn(std::string const& sql)
    {
        message msg;
        std::vector<std::string> value;
        int rc(sqlite3_exec(this->d_database, sql.c_str(), column_callback, &value, &msg));
        if (rc != SQLITE_OK) {
            throw std::runtime_error("query failed: "
                                     "query='" + sql + "' "
                                     "message='" + msg.str() + "'");
        }
        return value;
    }
}

// ----------------------------------------------------------------------------

SpeedyCrew::Database::Transaction::Transaction(SpeedyCrew::Database& db)
    : m_db(&db) {
    this->m_db->execute("BEGIN TRANSACTION;");
}

SpeedyCrew::Database::Transaction::Transaction(SpeedyCrew::Database* db)
    : m_db(db) {
    this->m_db->execute("BEGIN TRANSACTION;");
}

SpeedyCrew::Database::Transaction::~Transaction()
{
    if (this->m_db) {
        this->m_db->execute("ROLLBACK;");
    }
}

void SpeedyCrew::Database::Transaction::commit()
{
    this->m_db->execute("COMMIT;");
    this->m_db = 0;
}
