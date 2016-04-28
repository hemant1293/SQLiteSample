//
//  DBManager.h
//  SQLite
//
//  Created by Hemant Kumar on 19/04/16.
//  Copyright © 2016 hemant. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DBManager : NSObject
@property (nonatomic) int affectedRows;
@property (nonatomic) long long lastInsertedRowID;

-(instancetype)initWithDatabaseFilename:(NSString *)dbFilename;
-(NSArray *)readQuery:(const char *)query;
-(void)executeQuery:(NSString *)query;
-(void)writeQuery:(const char *)query withData:(NSData *)blob withKey:(NSString *) key;
@end
