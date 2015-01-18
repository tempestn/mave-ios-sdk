//
//  MAVEABTableViewController.h
//  MaveSDKDevApp
//
//  Created by dannycosson on 9/25/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MAVEInviteTableHeaderView.h"
#import "MAVEABPerson.h"

// This view controller can alert an additional delegate when the number of people selected changes
@protocol MAVEABTableViewAdditionalDelegate <NSObject>
@required
- (void)ABTableViewControllerNumberSelectedChanged:(unsigned long)num;
@end

@interface MAVEABTableViewController : NSObject <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UISearchDisplayDelegate, UITextFieldDelegate>

@property (nonatomic, weak) UIViewController<MAVEABTableViewAdditionalDelegate> *parentViewController;
@property (nonatomic, strong) MAVEInviteTableHeaderView *inviteTableHeaderView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *aboveTableContentView;
@property (nonatomic, assign) CGFloat contentInsetTopWithoutSearch;
@property (nonatomic, strong) NSMutableSet *selectedPhoneNumbers;

// For searching
@property (nonatomic, strong) NSArray *allPersons;
@property (nonatomic, strong) NSArray *searchedTableData;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *searchTableView;
@property (nonatomic, assign) BOOL isSearching;
@property (atomic, assign) BOOL isAnimatingSearchBarReplace;

- (instancetype)initTableViewWithParent:(UIViewController<MAVEABTableViewAdditionalDelegate> *)parent;

- (void)updateTableData:(NSDictionary *)data;
- (MAVEABPerson *)personOnTableView:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath;
- (void)layoutHeaderViewForWidth:(CGFloat)width;

// For searching
- (void)searchContacts:(NSString *)searchText;

@end