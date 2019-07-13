//
//  FSConferenceDataController.swift
//  hackertracker
//
//  Created by Christopher Mays on 6/19/19.
//  Copyright © 2019 Beezle Labs. All rights reserved.
//

import Foundation

import Firebase

class UpdateToken {
    fileprivate let collectionValue : Any;
    fileprivate init (_ collection : Any) {
        collectionValue = collection;
    }
}

class FSConferenceDataController {
    static let shared = FSConferenceDataController()
    var db: Firestore
    let conferenceQuery : Query?
    
    init() {
        db = Firestore.firestore()
        conferenceQuery = db.collection("conferences")
    }
    
    func requestConferences(updateHandler: @escaping (Result<[ConferenceModel], Error>) -> Void) -> UpdateToken {
        let query = db.collection("conferences")
        let conferences = Collection<ConferenceModel>(query: query)
        conferences.listen() { (changes) in
            updateHandler(Result<[ConferenceModel], Error>.success(conferences.items))
        }
        return UpdateToken(conferences);
    }
    
    func requestConferenceByCode(forCode conCode: String, updateHandler: @escaping (Result<ConferenceModel, Error>) -> Void) -> UpdateToken {
        let query = db.collection("conferences").whereField("code", isEqualTo: conCode)
        let conferences = Collection<ConferenceModel>(query: query)
        conferences.listen() { (changes) in
            updateHandler(Result<ConferenceModel, Error>.success(conferences.items.first!))
        }
        return UpdateToken(conferences);
    }
    
    func requestEvents(forConference conference: ConferenceModel, updateHandler: @escaping (Result<[HTEventModel], Error>) -> Void) -> UpdateToken {
        let query = document(forConference: conference).collection("events")
        let events = Collection<HTEventModel>(query: query)
        events.listen() { (changes) in
            updateHandler(Result<[HTEventModel], Error>.success(events.items))
        }
        return UpdateToken(events);
    }
    
    func requestEvents(forConference conference: ConferenceModel, eventId: Int, updateHandler: @escaping (Result<UserEventModel, Error>) -> Void) -> UpdateToken {
        var event : HTEventModel?
        var bookmark : Bookmark?
        
        let query = document(forConference: conference).collection("events").whereField("id", isEqualTo: eventId)
        let events = Collection<HTEventModel>(query: query)
        events.listen() { (changes) in
            event = events.items.first
            if let event = event {
                updateHandler(Result<UserEventModel, Error>.success(UserEventModel(event: event, bookmark: Bookmark(id: String(event.id), value: false))))
            }
        }
        
        guard let user = AnonymousSession.shared.user else {
            return UpdateToken(events)
        }
        
        let bookmarksQuery = document(forConference: conference).collection("users").document(user.uid).collection("bookmarks").whereField("id", isEqualTo: String(eventId))
        let bookmarksToken = Collection<Bookmark>(query: bookmarksQuery)
        bookmarksToken.listen { (changes) in
            bookmark = bookmarksToken.items.first
            if let event = event, let bookmark = bookmark {
                updateHandler(Result<UserEventModel, Error>.success(UserEventModel(event: event, bookmark: bookmark)))
            }
        }
        
        
        return UpdateToken([events, bookmarksToken]);
        
    }
    
    func requestSpeaker(forConference conference: ConferenceModel, speakerId: Int, updateHandler: @escaping (Result<HTSpeaker, Error>) -> Void) -> UpdateToken {
        let query = document(forConference: conference).collection("speakers").whereField("id", isEqualTo: speakerId)
        let speakers = Collection<HTSpeaker>(query: query)
        speakers.listen() { (changes) in
            updateHandler(Result<HTSpeaker, Error>.success(speakers.items.first!))
        }
        return UpdateToken(speakers);
    }
    
    func requestSpeakers(forConference conference: ConferenceModel, updateHandler: @escaping (Result<[HTSpeaker], Error>) -> Void) -> UpdateToken {
        let query = document(forConference: conference).collection("speakers").order(by: "name")
        let speakers = Collection<HTSpeaker>(query: query)
        speakers.listen() { (changes) in
            updateHandler(Result<[HTSpeaker], Error>.success(speakers.items))
        }
        return UpdateToken(speakers);
    }
    
    func requestEvents(forConference conference: ConferenceModel,
                       limit: Int? = nil,
                       descending: Bool = false,
                       updateHandler: @escaping (Result<[UserEventModel], Error>) -> Void) -> UpdateToken {
        var query: Query?
        query = document(forConference: conference).collection("events").order(by: "begin_timestamp", descending: descending).limit(to: limit ?? Int.max)
        
        return requestEvents(forConference: conference, query: query, updateHandler: updateHandler)
    }
    
    func requestEvents(forConference conference: ConferenceModel,
                       startDate: Date,
                       limit: Int? = nil,
                       descending: Bool = false,
                       updateHandler: @escaping (Result<[UserEventModel], Error>) -> Void) -> UpdateToken {
        var query: Query?
        query = document(forConference: conference).collection("events").whereField("begin_timestamp", isGreaterThan: startDate).order(by: "begin_timestamp", descending: descending).limit(to: limit ?? Int.max)
        
        return requestEvents(forConference: conference, query: query, updateHandler: updateHandler)
    }
    
    func requestEvents(forConference conference: ConferenceModel,
                       inDate: Date,
                       limit: Int? = nil,
                       descending: Bool = false,
                       updateHandler: @escaping (Result<[UserEventModel], Error>) -> Void) -> UpdateToken {
        var query: Query?
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: inDate)
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        query = document(forConference: conference).collection("events").whereField("begin_timestamp", isGreaterThan: start).whereField("begin_timestamp", isLessThan: end).order(by: "begin_timestamp", descending: descending).limit(to: limit ?? Int.max)
        
        return requestEvents(forConference: conference, query: query, updateHandler: updateHandler)
    }
    
    func requestEvents(forConference conference: ConferenceModel,
                       endDate: Date,
                       limit: Int? = nil,
                       descending: Bool = false,
                       updateHandler:  @escaping (Result<[UserEventModel], Error>) -> Void) -> UpdateToken {
        let query = document(forConference: conference).collection("events").whereField("end_timestamp", isLessThan: endDate).order(by: "end_timestamp", descending: descending).limit(to: limit ?? Int.max)
        return requestEvents(forConference: conference, query: query, updateHandler: updateHandler)
    }
    
    private func requestEvents(forConference conference: ConferenceModel,
                       query: Query?,
                       updateHandler: @escaping (Result<[UserEventModel], Error>) -> Void) -> UpdateToken {
       
        var events : [HTEventModel]?
        var bookmarks : [Bookmark]?
        
        let eventsToken = Collection<HTEventModel>(query: query!)

        eventsToken.listen() { (changes) in
            events = eventsToken.items
            if let events = events, let bookmarks = bookmarks {
                updateHandler(Result<[UserEventModel], Error>.success(self.createUserEvents(events: events, bookmarks: bookmarks)))
            }
        }
        
        guard let user = AnonymousSession.shared.user else {
            return UpdateToken(eventsToken)
        }
        
        let bookmarksQuery = document(forConference: conference).collection("users").document(user.uid).collection("bookmarks")
        let bookmarksToken = Collection<Bookmark>(query: bookmarksQuery)
        bookmarksToken.listen { (changes) in
            bookmarks = bookmarksToken.items
            if let events = events, let bookmarks = bookmarks {
                updateHandler(Result<[UserEventModel], Error>.success(self.createUserEvents(events: events, bookmarks: bookmarks)))
            }
        }
        
        
        return UpdateToken([eventsToken, bookmarksToken]);
    }
    
    func createUserEvents(events : [HTEventModel], bookmarks : [Bookmark]) -> [UserEventModel] {
        var bookmarkIndex = [String: Bookmark]()
        
        for bookmark in bookmarks {
            bookmarkIndex[bookmark.id] = bookmark
        }
        
        
        return events.map({ (eventModel) -> UserEventModel in
            return UserEventModel(event: eventModel, bookmark: bookmarkIndex[String(eventModel.id)] ?? Bookmark(id: String(eventModel.id), value: false))
        })
    }
    
    func requestLocations(forConference conference: ConferenceModel, updateHandler: @escaping (Result<[HTLocationModel], Error>) -> Void) -> UpdateToken {
        let query = document(forConference: conference).collection("locations")
        let events = Collection<HTLocationModel>(query: query)
        events.listen() { (changes) in
            updateHandler(Result<[HTLocationModel], Error>.success(events.items))
        }
        return UpdateToken(events);
    }
    
    func requestFavorites(forConference conference: ConferenceModel,
                          session: AnonymousSession,
                          updateHandler: @escaping (Result<[Bookmark], Error>) -> Void) -> UpdateToken? {
        guard let user = session.user else {
            return nil;
        }
        
        let query = document(forConference: conference).collection("users").document(user.uid).collection("bookmarks")
        let bookmarks = Collection<Bookmark>(query: query)
        bookmarks.listen { (changes) in
            updateHandler(Result<[Bookmark], Error>.success(bookmarks.items))
        }
        return UpdateToken(bookmarks);
    }
    
    func setFavorite(forConference conference: ConferenceModel,
                     eventModel: HTEventModel,
                     isFavorite: Bool,
                     session: AnonymousSession,
                     updateHandler: @escaping (Error?) -> Void) {
        guard let user = session.user else {
            return
        }
        document(forConference: conference).collection("users").document(user.uid).collection("bookmarks").document(String(eventModel.id)).setData([
            "id" : String(eventModel.id),
            "value" : isFavorite
        ]){ err in
            if let err = err {
                updateHandler(err)
            } else {
                updateHandler(nil)
            }
        }
    }
    
    private func document(forConference conference: ConferenceModel) -> DocumentReference {
        return db.collection("conferences").document(conference.code);
    }
}
