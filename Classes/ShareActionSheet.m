/* ShareActionSheet.m - Display an share action sheet
 * 
 * Copyright 2011 Last.fm Ltd.
 *   - Primarily authored by Sam Steele <sam@last.fm>
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MobileLastFM.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "ShareActionSheet.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAPI.h"
#endif


@implementation ShareActionSheet

@synthesize viewController;

- (ShareActionSheet*)initSuperWithTitle:(NSString*)title {
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [NSClassFromString(@"MFMailComposeViewController") canSendMail]) {
		self = [super initWithTitle:title
											delegate:self
								   cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
							  destructiveButtonTitle:nil
								   otherButtonTitles:@"E-mail Address", NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	} else {
		self = [super initWithTitle:title
											delegate:self
								   cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
							  destructiveButtonTitle:nil
								   otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	}
	return self;
}
- (id)initWithTrack:(NSString*)track byArtist:(NSString*)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share track sheet title")];
	if ( self ) {
		_track = [track retain];
		_artist = [artist retain];
		_album = nil;
	}
	return self;
}

- (id)initWithArtist:(NSString*)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"Who would you like to share this artist with?", @"Share artist sheet title") ];
	if ( self ) {
		_track = nil;
		_album = nil;
		_artist = [artist retain];
	}
	return self;
}

- (id)initWithAlbum:(NSString*)album byArtist:(NSString *)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"Who would you like to share this album with?", @"Share album sheet title") ];
	if ( self ) {
		_track = nil;
		_album = [album retain];
		_artist = [artist retain];
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated {
	barStyle = [UIApplication sharedApplication].statusBarStyle;
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Contacts", @"Share to Address Book")] ||
	   [[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"E-mail Address"]) {
		[self shareToAddressBook];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend")]) {
		[self shareToFriend];
	}
}

- (void)shareToAddressBook {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAPI logEvent:@"share-addressbook"];
#endif
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [MFMailComposeViewController canSendMail]) {
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
		MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
		[mail setMailComposeDelegate:self];
		
		NSString* sharedItem;
		if ( _track ) sharedItem = _track;
		else if ( _album ) sharedItem = _album;
		else sharedItem = _track;
		
		[mail setSubject:[NSString stringWithFormat:@"Last.fm: %@ shared %@",[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"], sharedItem]];
		NSString* sharedLink;
		if( _track ) {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@/_/%@'>%@</a>", 
													[_artist URLEscaped], [_track URLEscaped], _track];
		} else if ( _album ) {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@/%@'>%@</a>", 
						  [_artist URLEscaped], [_album URLEscaped], _album];
		} else {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@'>%@</a>", 
						  [_artist URLEscaped], _artist];
		}
		[mail setMessageBody:[NSString stringWithFormat:@"<p>Hi there,</p>\
							  <p>%@ has shared %@ with you on Last.fm!</p>\
							  <p>Click the link for more information about this music.</p>\
							  <p>Don't have a Last.fm account?<br/>\
							  Last.fm helps you find new music, effortlessly keeping a record of what you listen to from almost any player.</p>\
							  </p><a href='http://www.last.fm/join'>Join Last.fm for free</a> and create a music profile.</p>\
							  <p>- The Last.fm Team</p>",
							  [[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"],
							  sharedLink
							  ] isHTML:YES];
		[self retain];
		[viewController presentModalViewController:mail animated:YES];
		[mail release];
	} else {
		ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
		peoplePicker.displayedProperties = [NSArray arrayWithObjects:[NSNumber numberWithInteger:kABPersonEmailProperty], nil];
		peoplePicker.peoplePickerDelegate = self;
		[viewController presentModalViewController:peoplePicker animated:YES];
		[peoplePicker release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return YES;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	ABMultiValueRef value = ABRecordCopyValue(person, property);
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(value, ABMultiValueGetIndexForIdentifier(value, identifier));
	[viewController dismissModalViewControllerAnimated:YES];
	
	if( _track ) {
		[[LastFMService sharedInstance] recommendTrack:_track
											  byArtist:_artist
										toEmailAddress:email];
	} else if ( _album ) {
		[[LastFMService sharedInstance] recommendAlbum:_album
											  byArtist:_artist
										toEmailAddress:email];			
	} else {
		[[LastFMService sharedInstance] recommendArtist:_artist
										 toEmailAddress:email ];
	}
	[email release];
	CFRelease(value);
	
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	return NO;
}
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self release];
	[viewController becomeFirstResponder];
	[viewController dismissModalViewControllerAnimated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)shareToFriend {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAPI logEvent:@"share-friend"];
#endif
	FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if(friends) {
		friends.delegate = self;
		friends.title = NSLocalizedString(@"Choose A Friend", @"Friend selector title");
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:friends];
		[friends release];
		[viewController presentModalViewController:nav animated:YES];
		[nav release];
		[[UIApplication sharedApplication] setStatusBarStyle:barStyle animated:YES];
	}
}

- (void)friendsViewController:(FriendsViewController *)friends didSelectFriend:(NSString *)username {
	if( _track ) {
		[[LastFMService sharedInstance] recommendTrack:_track
											  byArtist:_artist
										toEmailAddress:username];
	} else if ( _album ) {
		[[LastFMService sharedInstance] recommendAlbum:_album
											  byArtist:_artist
										toEmailAddress:username];
	} else {
		[[LastFMService sharedInstance] recommendArtist:_artist
										 toEmailAddress:username];		
	}
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	
	[[UIApplication sharedApplication] setStatusBarStyle:barStyle animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)friendsViewControllerDidCancel:(FriendsViewController *)friends {
	[[UIApplication sharedApplication] setStatusBarStyle:barStyle animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}

- (void)dealloc {
    [super dealloc];
	[_artist release];
	[_track release];
	[_album release];
}


@end
