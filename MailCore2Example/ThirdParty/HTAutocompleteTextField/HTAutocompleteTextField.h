//
//  HTAutocompleteTextField.h
//  HotelTonight
//
//  Created by Jonathan Sibley on 11/29/12.
//  Inspired by DOAutocompleteTextField by DoAT.
//
//  Copyright (c) 2012 Hotel Tonight. All rights reserved.
//

#import "WTReTextField.h"

@class  HTAutocompleteTextField;

@protocol HTAutocompleteTextFieldDelegate <NSObject>

@optional
- (void)autoCompleteTextFieldDidAutoComplete:(HTAutocompleteTextField *)autoCompleteField;
- (void)autocompleteTextField:(HTAutocompleteTextField *)autocompleteTextField didChangeAutocompleteText:(NSString *)autocompleteText;

@end

@interface HTAutocompleteTextField : WTReTextField
/*
 * A list of email domains to suggest
 */
@property (nonatomic, strong) NSArray *autocompleteArray; // modify to use your own custom list of email domains

/*
 * Designated programmatic initializer (also compatible with Interface Builder)
 */
- (id)initWithFrame:(CGRect)frame;

/*
 * Autocomplete behavior
 */
@property (nonatomic, assign) BOOL autocompleteDisabled;
@property (nonatomic, assign) BOOL ignoreCase;
@property (nonatomic, assign) BOOL showAutocompleteButton;
@property (nonatomic, assign) id<HTAutocompleteTextFieldDelegate> autoCompleteTextFieldDelegate;

/*
 * Configure text field appearance
 */
@property (nonatomic, strong) UILabel *autocompleteLabel;
- (void)setFont:(UIFont *)font;
@property (nonatomic, assign) CGPoint autocompleteTextOffset;

/*
 * Subclassing:
 */
- (CGRect)autocompleteRectForBounds:(CGRect)bounds; // Override to alter the position of the autocomplete text
- (void)setupAutocompleteTextField; // Override to perform setup tasks.  Don't forget to call super.

/*
 * Refresh the autocomplete text manually (useful if you want the text to change while the user isn't editing the text)
 */
- (void)forceRefreshAutocompleteText;

@end