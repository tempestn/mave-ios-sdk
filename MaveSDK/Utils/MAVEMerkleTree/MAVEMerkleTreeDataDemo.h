//
//  MAVEMerkleTreeDataDemo.h
//  MaveSDK
//
//  Created by Danny Cosson on 1/27/15.
//
//

#import <Foundation/Foundation.h>
#import "MAVEMerkleTreeProtocols.h"

// This is a demo class to show how to implement
// MAVEMerkleTreeDataItem
// It's just an object wrapper around an NSUInteger
@interface MAVEMerkleTreeDataDemo : NSObject<MAVEMerkleTreeDataItem>

@property (nonatomic, assign) NSUInteger value;

- (instancetype)initWithValue:(NSUInteger)value;

@end