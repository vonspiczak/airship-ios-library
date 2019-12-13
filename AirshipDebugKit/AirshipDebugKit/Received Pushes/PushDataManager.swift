/* Copyright Airship and Contributors */

import UIKit
import CoreData
import AirshipKit

protocol PushDataManagerDelegate {
    func pushAdded()
}

class PushDataManager: NSObject {
    private let pushKey = "pushes"
    private let pushNotificationName = "UAPushAdded"

    private let storageDaysSettingKey = "AirshipDebugKit-PushNotificationStorageDays"

    // The number of days events will be stored by default.
    private let defaultStorageDays = 2

    // Days of event backlog - must be greater than or equal to the default of 2 days.
    var storageDays:Int {
        get {
            let persisted = UserDefaults.standard.integer(forKey:storageDaysSettingKey)
            return persisted >= defaultStorageDays ? persisted : defaultStorageDays
        }

        set (storageDays) {
            UserDefaults.standard.set(storageDays, forKey: storageDaysSettingKey)
        }
    }

    var delegate:PushDataManagerDelegate?

    static let shared = PushDataManager()

    private lazy var persistentContainer:NSPersistentContainer = {
        let momdName = "DebugPushData"

        guard let modelURL = Bundle(for: type(of: self)).url(forResource: momdName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }

        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }

        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)

        container.loadPersistentStores(completionHandler: { (storeDescriptioon, error) in
            if let error = error as NSError? {
                print("ERROR: error loading Debug Kit Data Manager persistent stores - \(error), \(error.userInfo)")
            }
        })

        return container
    }()

    override init() {
        super.init()
    }

    private func saveContext(_ context:NSManagedObjectContext) {
        guard context.hasChanges else {
            return
        }

        do {
            try context.save()
        } catch {
            if let error = error as NSError? {
                print("ERROR: error saving Debug Kit Data Manager context - \(error), \(error.userInfo)")
            }
        }
    }

    private func batchDeletePushNotificationsOlderThanStorageDays() {
        let context = persistentContainer.viewContext

        let startOfTodayDate = Calendar.current.startOfDay(for: Date())

        // Storage days defaults to 2
        let storageDaysInterval = Calendar.current.date(byAdding:.day, value:-(self.storageDays), to:startOfTodayDate)!.timeIntervalSince1970

        print("Deleting push notifications older than \(storageDays) days.")

        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = PushData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format:"time < %f", storageDaysInterval)
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest:fetchRequest)

        do {
            _ = try context.execute(batchDeleteRequest)
        } catch {
            print("Failed to execute request: \(error)")
        }
    }

    public func savePushNotification(_ push:PushNotification) {
        
        let context = persistentContainer.viewContext
        
        let persistedPush = PushData(entity: PushData.entity(), insertInto:context)

        if(!somePushExists(id: push.pushID)) {
            
            persistedPush.pushID = push.pushID
            persistedPush.alert = push.alert
            persistedPush.data = push.data
            persistedPush.time = push.time

            saveContext(context)
        }
    }
    
    func somePushExists(id: String) -> Bool {
        var pushDatas:[Any] = []
        var pushes:[PushNotification] = []

        let context = persistentContainer.viewContext
        let fetchRequest:NSFetchRequest = PushData.fetchRequest()

        fetchRequest.predicate = NSPredicate(format: "pushID = %@", id)

        var results: [NSManagedObject] = []

        do {
            results = try context.fetch(fetchRequest)
        }
        catch {
            print("error executing fetch request: \(error)")
        }

        return results.count > 0
    }

    func fetchAllPushNotifications() -> [PushNotification] {
        return fetchPushesContaining()
    }
    
    func fetchPushesContaining() -> [PushNotification] {
        var pushDatas:[Any] = []
        var pushes:[PushNotification] = []

        let context = persistentContainer.viewContext
        let sort = NSSortDescriptor(key: "time", ascending: false)
        let sortDescriptors = [sort]
        let fetchRequest:NSFetchRequest = PushData.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        do {
            pushDatas = try context.fetch(fetchRequest)
        } catch {
            if let error = error as NSError? {
                print("ERROR: error fetching events list - \(error), \(error.userInfo)")
            }
        }

        for pushData in pushDatas {
            guard let data = pushData as? PushData else {
                continue
            }

            let push = PushNotification(pushData:data)
            pushes.append(push)
        }

        return pushes
    }
}
