//
//  ViewController.m
//  SQLite
//
//  Created by Hemant Kumar on 19/04/16.
//  Copyright © 2016 hemant. All rights reserved.
//

#import "ViewController.h"
#import "DBManager.h"

@interface ViewController ()

@property (nonatomic, strong) DBManager *dbManager;
@property (nonatomic, strong) dispatch_queue_t  concurrentQueue;
@property (nonatomic, strong) NSArray *result;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *value;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // DBManager
    self.dbManager = [[DBManager alloc] initWithDatabaseFilename:@"myDictionary.sql"];
    self.concurrentQueue = dispatch_queue_create("com.SQLite.query",
                                                      DISPATCH_QUEUE_CONCURRENT);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) writeData {
    // Convert valueArray into data/bytes. value array can be anything like string, array or dictionary
    NSData *valueObj;
    if (self.key && self.value) {
        valueObj = [NSKeyedArchiver archivedDataWithRootObject:self.value];
    } else {
        NSLog(@"Key or value is nil.");
        return;
    }
    
    // Prepare the query string.
    NSString *query;
    if (valueObj) {
        query = [NSString stringWithFormat:@"insert into keyValue (key, value) values('%@', ?)", self.key];
    }
    
    dispatch_barrier_async(self.concurrentQueue, ^{
        if (query) {
            [self.dbManager writeQuery:[query UTF8String] withData:valueObj withKey:self.key];
        }

        // If the query was successfully executed then pop the view controller.
        if (self.dbManager.affectedRows != 0) {
            NSLog(@"Query was executed successfully. Affected rows = %d", self.dbManager.affectedRows);
        }
        else{
            NSLog(@"Could not execute the query.");
        }
    });
}

-(void)readData{
    // Prepare the query string.
    NSString *query;
    if (self.key && [self.key length] > 0) {
        query= [NSString stringWithFormat:@"select value from keyValue where key = '%@'", self.key];
    }
    dispatch_async(self.concurrentQueue, ^{
        if (query) {
            NSArray *result = [[NSArray alloc] initWithArray:[self.dbManager readQuery:[query UTF8String]]];
            // If the query was successfully executed and returned result.
            if (result && [result count] > 0) {
                [self convertDataIntoObject:result];
            } else {
                 NSLog(@"No key value pair found.");
            }
        }
    });
}

-(void) convertDataIntoObject:(NSArray *) result {
    NSData *value = [[result objectAtIndex:0] objectAtIndex:0];
    
    NSObject *finalValue = [NSKeyedUnarchiver unarchiveObjectWithData:value];
    
    self.result = [[NSArray alloc] initWithObjects:finalValue, nil];
}
@end
