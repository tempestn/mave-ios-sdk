//
//  GRKABTableViewControllerTests.m
//  GrowthKit
//
//  Created by Danny Cosson on 10/23/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "GRKInvitePageViewController.h"
#import "GRKABTableViewController.h"
#import "GRKABPerson.h"

@interface GRKABTableViewControllerTests : XCTestCase

@end

@implementation GRKABTableViewControllerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testClickDidSelectRowAtIndexPath {
    // selecting the row should toggle the corresponding person's selected attribute and call
    // a method on the parent to inform of the update

    // Set up data
    id mockedIPVC = [OCMockObject mockForClass:[GRKInvitePageViewController class]];
    id mockedTableView = [OCMockObject mockForClass:[UITableView class]];
    CGRect noFrame = CGRectMake(0, 0, 0, 0);
    GRKABTableViewController *vc = [[GRKABTableViewController alloc] initTableViewWithFrame:noFrame parent:mockedIPVC];
    GRKABPerson *p1 = [[GRKABPerson alloc] init];
    p1.firstName = @"Abbie"; p1.lastName = @"Foo";
    p1.phoneNumbers = @[@"18085551234"]; p1.selected = NO;
    [vc updateTableData:@{@"A": @[p1]}];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];

    XCTAssertEqual([vc.selectedPhoneNumbers count], 0);
    [[mockedIPVC expect] ABTableViewControllerNumberSelectedChanged:1];
    [[mockedTableView expect] reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    
    // Run
    [vc tableView:nil didSelectRowAtIndexPath:indexPath];
    
    // Verify
    XCTAssertEqualObjects(vc.selectedPhoneNumbers, [NSSet setWithArray:@[@"18085551234"]]);
    [mockedIPVC verify];
}

@end
