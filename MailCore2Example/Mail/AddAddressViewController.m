//
//  AddAddressViewController.m
//  CECiTurbo
//
//  Created by DongXing on 5/5/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "AddAddressViewController.h"
#import <AddressBook/AddressBook.h>

@interface AddAddressViewController () <UISearchResultsUpdating,UISearchBarDelegate>
{
    NSArray *addressBookItems;
    NSArray *searchResults;
    
    BOOL searching;
}
@property (strong, nonatomic) UISearchController *searchController;

@end

@implementation AddAddressViewController
static NSString *CellReuseIdentifier = @"AddressSearchCell";

- (void)viewDidLoad {
    [super viewDidLoad];

    searching = NO;
    
    if ([ApplicationDirector isIOS8OrHigher]){
        self.tableView.estimatedRowHeight = 44.0f;
        self.tableView.rowHeight = UITableViewAutomaticDimension;
    }
    
    // No search results controller to display the search results in the current view
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    [self.searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.definesPresentationContext = YES;
    
    // iPhone聯絡人
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, nil);
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            [self getAddressBook:addressBook];
        });
    } else if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
        [self getAddressBook:addressBook];
    }
}

- (void)getAddressBook:(ABAddressBookRef)addressBook {
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople( addressBook );
    CFIndex nPeople = ABAddressBookGetPersonCount( addressBook );

    NSMutableArray *mutEmails = [[NSMutableArray alloc] init];
    
    for ( int i = 0; i < nPeople; i++ )
    {
        ABRecordRef person = CFArrayGetValueAtIndex( allPeople, i );
        
        NSString *firstName = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonFirstNameProperty));
        NSString *lastName = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonLastNameProperty));
        if (!firstName){
            firstName = @"";
        }
        if (!lastName) {
            lastName = @"";
        }
        
        ABMultiValueRef emailMultiValue = ABRecordCopyValue(person, kABPersonEmailProperty);
        NSArray *emailAddresses = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(emailMultiValue);
        CFRelease(emailMultiValue);
        
        for (NSString* email in emailAddresses){
            MCOAddress *address = [MCOAddress addressWithDisplayName:[NSString stringWithFormat:@"%@ %@", firstName, lastName] mailbox:email];
            [mutEmails addObject:address];
        }
    }
    
    [self fillEmailsListWithData:[NSSet setWithArray:mutEmails]];
}

- (void)fillEmailsListWithData:(NSSet *)mailsSet
{
    if (addressBookItems.count > 0)
    {
        NSMutableSet *existingEmails = [NSMutableSet setWithArray:addressBookItems];
        [existingEmails unionSet:mailsSet];
        
        addressBookItems = [[existingEmails allObjects] sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES]]];
    }
    else
    {
        addressBookItems = [[mailsSet allObjects] sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES]]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshView:(UIRefreshControl*)refreshControl{
    [refreshControl beginRefreshing];
    //[refreshControl endRefreshing];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.searchController.active)
    {
        return [searchResults count];
    }
    
    return [addressBookItems count];
}

- (IBAction)buttonCancelAction:(UIBarButtonItem *)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellReuseIdentifier forIndexPath:indexPath];
    
    MCOAddress *info;
    if (self.searchController.active)
    {
        info = [searchResults objectAtIndex:indexPath.row];
    }
    else
    {
        info = [addressBookItems objectAtIndex:indexPath.row];
    }

    cell.textLabel.text = [info displayName];
    cell.detailTextLabel.text = [info mailbox];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    MCOAddress *info;
    if (self.searchController.active)
    {
        info = [searchResults objectAtIndex:indexPath.row];
    }
    else
    {
        info = [addressBookItems objectAtIndex:indexPath.row];
    }
    if (info && self.delegate && [self.delegate respondsToSelector:@selector(addAddressComplete:with:)]) {
        [self.delegate addAddressComplete:self.bindTextField with:info];
    }
    
    [self.searchController setActive:NO];
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    if (searchText.length) {
        NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"displayName contains[c] %@ OR mailbox contains[c] %@", searchText ,searchText];
        searchResults = [addressBookItems filteredArrayUsingPredicate:resultPredicate];
    }else{
        searchResults = addressBookItems;
    }
    
    [self.tableView reloadData];
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController{
    
    [self filterContentForSearchText:searchController.searchBar.text
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar
                                                     selectedScopeButtonIndex]]];
}

@end
