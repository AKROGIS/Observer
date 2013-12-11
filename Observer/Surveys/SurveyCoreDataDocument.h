//
//  SurveyCoreDataDocument.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

// A SurveyCoreDataDocument overrides UIManagedDocument to provide a custom Object Model
// The xcdatamodeld file in the application bundle provides a default schema for all
// surveys, however each survey adds a unique collection of attributes for the default
// entities.

// Subclasses to UIManagedDocument override managedObjectModel to provide a specifc
// object model for the subclass.  Unfortunately, this method is called by the designated
// initializer in UIManagedDocument, so there is no way to set a property in the subclass
// that can be used in managedObjectModel to control this creation.

// Since this UIManagedDocument is a sub-document of the survey (and will always be in a sub-
// folder of the survey), I can use url (provided in the initializer) to get the relevant
// survey from the singleton SurveyCollection.  I can then use the survey's protocol to
// create the object model.


#import <UIKit/UIKit.h>

@interface SurveyCoreDataDocument : UIManagedDocument

@end
