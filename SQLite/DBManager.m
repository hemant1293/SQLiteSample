//
//  DBManager.m
//  SQLite
//
//  Created by Hemant Kumar on 19/04/16.
//  Copyright © 2016 hemant. All rights reserved.
//

#import "DBManager.h"
#import <sqlite3.h>

@interface DBManager()

@property (nonatomic, strong) NSString *documentsDirectory;
@property (nonatomic, strong) NSString *databaseFilename;
@property (nonatomic, strong) NSMutableArray *arrResults;

-(void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable;
-(void)copyDatabaseIntoDocumentsDirectory;

@end

@implementation DBManager

-(instancetype)initWithDatabaseFilename:(NSString *)dbFilename{
    self = [super init];
    if (self) {
        
        // Set the documents directory path to the documentsDirectory property.
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        self.documentsDirectory = [paths objectAtIndex:0];
        
        // Keep the database filename.
        self.databaseFilename = dbFilename;
        
        // Copy the database file into the documents directory if necessary.
        [self copyDatabaseIntoDocumentsDirectory];
    }
    return self;
}

-(void) executeTransaction:(NSString *)query  withKeys:(NSArray *) keyValues{
    
    sqlite3 *sqlite3Database;
    
    // Set the database file path.
    NSString *databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
    
    // Open the database.
    BOOL openDatabaseResult = sqlite3_open([databasePath UTF8String], &sqlite3Database);
    
    if(openDatabaseResult == SQLITE_OK) {
        // Declare a sqlite3_stmt object in which will be stored the query after having been compiled into a SQLite statement.
        sqlite3_stmt *compiledStatement;
        
        sqlite3_exec(sqlite3Database, "BEGIN EXCLUSIVE TRANSACTION", 0, 0, 0);
        // Load all data from database to memory.
        BOOL prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, [query UTF8String], -1, &compiledStatement, NULL);
        if(prepareStatementResult == SQLITE_OK) {
            for (NSArray *obj in keyValues)
            {
                sqlite3_bind_text(compiledStatement, 1, [[obj objectAtIndex:0]UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_blob(compiledStatement, 2, [[obj objectAtIndex:1] bytes], (int)[[obj objectAtIndex:1] length], SQLITE_TRANSIENT);
                if (sqlite3_step(compiledStatement) != SQLITE_DONE) {
                    // If could not execute the query show the error message on the debugger.
                    NSString *error = [NSString stringWithFormat:@"%s", sqlite3_errmsg(sqlite3Database)];
                    if ( [error isEqualToString:@"UNIQUE constraint failed: keyValue.key"]) {
                        NSString *new_query = [NSString stringWithFormat:@"delete from keyValue where key = '%@'", [obj objectAtIndex:0]];
                        [self deleteARow:[new_query UTF8String]];
                    } else {
                        NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
                    }

                }
                if (sqlite3_reset(compiledStatement) != SQLITE_OK) NSLog(@"SQL Error: %s",sqlite3_errmsg(sqlite3Database));
            }
        }
        else {
            // In the database cannot be opened then show the error message on the debugger.
            NSLog(@"%s", sqlite3_errmsg(sqlite3Database));
        }
        
        // Release the compiled statement from memory.
        sqlite3_finalize(compiledStatement);
       
        if (sqlite3_exec(sqlite3Database, "COMMIT TRANSACTION", 0, 0, 0) != SQLITE_OK) NSLog(@"SQL Error: %s",sqlite3_errmsg(sqlite3Database));
        
    }
    // Close the database.
    sqlite3_close(sqlite3Database);
    
//    sqlite3_exec(db, "BEGIN EXCLUSIVE TRANSACTION", 0, 0, 0);
//    if(sqlite3_prepare(db, query, -1, &compiledStatement, NULL) == SQLITE_OK)
//    {
//        for (someObject *obj in uArray)
//        {
//            sqlite3_bind_int(compiledStatement, 1, [obj value1]);
//            sqlite3_bind_int(compiledStatement, 2, [obj value2]);
//            if (sqlite3_step(compiledStatement) != SQLITE_DONE) NSLog(@"DB not updated. Error: %s",sqlite3_errmsg(db));
//            if (sqlite3_reset(compiledStatement) != SQLITE_OK) NSLog(@"SQL Error: %s",sqlite3_errmsg(db));
//        }
//    }
//    if (sqlite3_finalize(compiledStatement) != SQLITE_OK) NSLog(@"SQL Error: %s",sqlite3_errmsg(db));
//    if (sqlite3_exec(db, "COMMIT TRANSACTION", 0, 0, 0) != SQLITE_OK) NSLog(@"SQL Error: %s",sqlite3_errmsg(db));
//    sqlite3_close(db);
}

-(void)copyDatabaseIntoDocumentsDirectory{
    // Check if the database file exists in the documents directory.
    NSString *destinationPath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
    if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        // The database file does not exist in the documents directory, so copy it from the main bundle now.
        NSString *sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.databaseFilename];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:destinationPath error:&error];
        
        // Check if any error occurred during copying and display it.
        if (error != nil) {
            NSLog(@"%@", [error localizedDescription]);
        }
    }
}

-(NSArray *)readQuery:(const char *)query{
    // Create a sqlite object.
    sqlite3 *sqlite3Database;
    
    // Set the database file path.
    NSString *databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
    
    // Initialize the results array.
    if (self.arrResults != nil) {
        [self.arrResults removeAllObjects];
        self.arrResults = nil;
    }
    self.arrResults = [[NSMutableArray alloc] init];
    
    // Open the database.
    BOOL openDatabaseResult = sqlite3_open([databasePath UTF8String], &sqlite3Database);
    if(openDatabaseResult == SQLITE_OK) {
        // Declare a sqlite3_stmt object in which will be stored the query after having been compiled into a SQLite statement.
        sqlite3_stmt *compiledStatement;
        
        // Load all data from database to memory.
        BOOL prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL);
        if(prepareStatementResult == SQLITE_OK) {
            // In this case data must be loaded from the database.
            
            // Declare an array to keep the data for each fetched row.
            NSMutableArray *arrDataRow;
            
            // Loop through the results and add them to the results array row by row.
            while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
                // Initialize the mutable array that will contain the data of a fetched row.
                arrDataRow = [[NSMutableArray alloc] init];
                
                const void *ptr = sqlite3_column_blob(compiledStatement, 0);
                int size = sqlite3_column_bytes(compiledStatement, 0);
                NSData *data = [[NSData alloc] initWithBytes:ptr length:size];
                if (data) {
                    [arrDataRow addObject:data];
                }
                
                // Store each fetched data row in the results array, but first check if there is actually data.
                if (arrDataRow.count > 0) {
                    [self.arrResults addObject:arrDataRow];
                }
            }
        }
        else {
            // In the database cannot be opened then show the error message on the debugger.
            NSLog(@"%s", sqlite3_errmsg(sqlite3Database));
        }
        
        // Release the compiled statement from memory.
        sqlite3_finalize(compiledStatement);
        
    }
    
    // Close the database.
    sqlite3_close(sqlite3Database);
    
    return self.arrResults;
}


-(void)writeQuery:(const char *)query withData:(NSData *)blob withKey:(NSString *) key {
    // Create a sqlite object.
    sqlite3 *sqlite3Database;
    
    // Set the database file path.
    NSString *databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
    
    // Open the database.
    BOOL openDatabaseResult = sqlite3_open([databasePath UTF8String], &sqlite3Database);

    if(openDatabaseResult == SQLITE_OK) {
        // Declare a sqlite3_stmt object in which will be stored the query after having been compiled into a SQLite statement.
        sqlite3_stmt *compiledStatement;
        
        // Load all data from database to memory.
        BOOL prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL);
        if(prepareStatementResult == SQLITE_OK) {
            sqlite3_bind_blob(compiledStatement, 1, [blob bytes], (int)[blob length], SQLITE_TRANSIENT);
            
            if (sqlite3_step(compiledStatement) == SQLITE_DONE) {
                // Keep the affected rows.
                self.affectedRows = sqlite3_changes(sqlite3Database);
                
                // Keep the last inserted row ID.
                self.lastInsertedRowID = sqlite3_last_insert_rowid(sqlite3Database);
            }
            else {
                // If could not execute the query show the error message on the debugger.
                NSString *error = [NSString stringWithFormat:@"%s", sqlite3_errmsg(sqlite3Database)];
                if ( [error isEqualToString:@"UNIQUE constraint failed: keyValue.key"]) {
                    NSString *new_query = [NSString stringWithFormat:@"delete from keyValue where key = '%@'", key];
                    [self deleteARow:[new_query UTF8String]];
                    [self writeQuery:query withData:blob withKey:key];
                } else {
                    NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
                }
            }
        }
        else {
            // In the database cannot be opened then show the error message on the debugger.
            NSLog(@"%s", sqlite3_errmsg(sqlite3Database));
        }
        // Release the compiled statement from memory.
        sqlite3_finalize(compiledStatement);
        
    }
    // Close the database.
    sqlite3_close(sqlite3Database);
}

-(void) deleteARow:(const char *) query {
    
    sqlite3 *sqlite3Database;
    
    // Set the database file path.
    NSString *databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
    
    // Open the database.
    BOOL openDatabaseResult = sqlite3_open([databasePath UTF8String], &sqlite3Database);
    
    sqlite3_stmt *compiledStatement;
    
    if(openDatabaseResult == SQLITE_OK) {
        sqlite3_prepare_v2(sqlite3Database, query, -1, & compiledStatement, NULL);
        if (sqlite3_step(compiledStatement) == SQLITE_DONE)
        {
            NSLog(@"Row is deleted successfully");
        } else {
            NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
        }
        // Release the compiled statement from memory.
        sqlite3_finalize(compiledStatement);
    }
    // Close the database.
    sqlite3_close(sqlite3Database);
}

@end
