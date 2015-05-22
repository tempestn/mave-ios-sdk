//
//  MAVEContactsInvitePageV3ViewController.m
//  MaveSDK
//
//  Created by Danny Cosson on 5/21/15.
//
//

#import "MAVEContactsInvitePageV3ViewController.h"
#import "MAVEContactsInvitePageV3TableWrapperView.h"
#import "MAVEContactsInvitePageV3Cell.h"
#import "MAVEABPermissionPromptHandler.h"
#import "MAVEInvitePageViewController.h"

NSString * const MAVEContactsInvitePageV3CellIdentifier = @"MAVEContactsInvitePageV3CellIdentifier";

@interface MAVEContactsInvitePageV3ViewController ()

@end

@implementation MAVEContactsInvitePageV3ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.dataManager = [[MAVEContactsInvitePageDataManager alloc] init];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[MAVEContactsInvitePageV3Cell class]
           forCellReuseIdentifier:MAVEContactsInvitePageV3CellIdentifier];

    self.sampleCell = [[MAVEContactsInvitePageV3Cell alloc] init];

    [self loadContactsData];
}

- (void)loadView {
    self.view = [[MAVEContactsInvitePageV3TableWrapperView alloc] init];
}
- (UITableView *)tableView {
    return ((MAVEContactsInvitePageV3TableWrapperView *)self.view).tableView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Loading Contacts Data
- (void)loadContactsData {
    [MAVEABPermissionPromptHandler promptForContactsWithCompletionBlock: ^(NSArray *contacts) {
        [self.dataManager updateWithContacts:contacts ifNecessaryAsyncSuggestionsBlock:nil];
    }];
}
- (MAVEABPerson *)personAtIndexPath:(NSIndexPath *)indexPath {
    return [self.dataManager personAtMainTableIndexPath:indexPath];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [self.dataManager sectionIndexesForMainTable];
}

#pragma mark - Table View Data Source & Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.dataManager numberOfSectionsInMainTable];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataManager numberOfRowsInMainTableSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *text = @"Foo";
    return [[MAVEInviteTableSectionHeaderView alloc] initWithLabelText:text sectionIsWaiting:NO];
 }

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    MAVEABPerson *person = [self personAtIndexPath:indexPath];
//    NSInteger numberContactInfoRecords = person.selected ? [person.phoneNumbers count] : 0;
    return [self.sampleCell heightGivenNumberOfContactInfoRecords:0];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MAVEContactsInvitePageV3Cell *cell = [tableView dequeueReusableCellWithIdentifier:MAVEContactsInvitePageV3CellIdentifier];
    MAVEABPerson *person = [self personAtIndexPath:indexPath];
    [cell updateForReuseWithPerson:person];
    return (UITableViewCell *)cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"selected row");
    MAVEABPerson *person = [self personAtIndexPath:indexPath];
    person.selected = !person.selected;

}

@end
