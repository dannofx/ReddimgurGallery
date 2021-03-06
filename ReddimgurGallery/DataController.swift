//
//  DataController.swift
//  RedImgurGallery
//
//  Created by Danno on 7/25/17.
//  Copyright © 2017 Daniel Heredia. All rights reserved.
//

import UIKit
import CoreData

class DataController: NSObject {
    let persistentContainer: NSPersistentContainer
    var viewContext: NSManagedObjectContext {
        return self.persistentContainer.viewContext
    }
    
    override init() {
        persistentContainer = NSPersistentContainer(name: "ImgurModel")
        super.init()
        persistentContainer.loadPersistentStores { (description, error) in
            if let error = error {
                print("Error: Error loading CoreData model \(error.localizedDescription)")
            }
        }
        self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Data access and modification

extension DataController {
    
    func insertImageItemData(data: [String: Any], context: NSManagedObjectContext) {
        context.automaticallyMergesChangesFromParent = true
        let image = NSEntityDescription.insertNewObject(forEntityName: String(describing: ImageItem.self), into: context) as! ImageItem
        image.title = data[JSONKey.title] as? String
        image.identifier = data[JSONKey.id] as? String
        image.datetime = data[JSONKey.datetime] as! TimeInterval
        image.views = data[JSONKey.views] as! Int64
        image.link = data[JSONKey.link] as? String
    }
    
    func findImageItem(withId id: String, context: NSManagedObjectContext) -> ImageItem? {
        let fetchRequest: NSFetchRequest<ImageItem> = ImageItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", id)
        fetchRequest.resultType = NSFetchRequestResultType.managedObjectResultType
        do  {
            let results = try context.fetch(fetchRequest)
            return results.count > 0 ? results.first! : nil
        } catch {
            print("Error fetching image result")
            return nil
        }
    }
    
    func createFeedFetchedResultController() -> NSFetchedResultsController<ImageItem> {
        let fetchRequest: NSFetchRequest<ImageItem> = ImageItem.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: #keyPath(ImageItem.datetime), ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                 managedObjectContext: self.viewContext,
                                                                 sectionNameKeyPath: nil,
                                                                 cacheName: nil)
        do {
            try fetchedResultController.performFetch()
        } catch {
            print("Error fetching image items")
        }
        
        return fetchedResultController
    }
    
    func deleteAllImageItems(completionBlock: ((_ success: Bool) -> Void)? = nil) {
        self.persistentContainer.performBackgroundTask { (context) in
            context.automaticallyMergesChangesFromParent = true
            let fetchRequest: NSFetchRequest<ImageItem> = ImageItem.fetchRequest()
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            do {
                try context.execute(batchDeleteRequest)
                self.viewContext.reset()
                //TODO: Check this solution https://stackoverflow.com/questions/33533750/core-data-nsbatchdeleterequest-appears-to-leave-objects-in-context
                completionBlock?(true)
            } catch {
                completionBlock?(false)
                print("Error: Error deleting records \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Context access

extension DataController {
    
    func saveContext() {
        let context = persistentContainer.viewContext
        _ = saveContext(context: context)
    }
    
    func saveContext(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                fatalError("Failure to save context: \(error)")
            }
        }
    }
}

// MARK: - Parsing and validation

extension DataController {
    
    func insertImageItemDataArray(dataArray: [[String: Any]], completion: @escaping (_ success: Bool, _ inserted: Int, _ error: Error?) -> Void) {
        self.persistentContainer.performBackgroundTask { (context) in
            context.automaticallyMergesChangesFromParent = true
            var batchChecked = false
            var insertedItems = 0
            for imageData in dataArray {
                if !self.checkIfValidImageData(data: imageData) {
                    continue
                }
                
                if !batchChecked {
                    let id = imageData[JSONKey.id] as! String
                    if let _ = self.findImageItem(withId: id, context: context) {
                        // An image exists, is a repeated batch
                        self.viewContext.perform {
                            completion(false, insertedItems, ImageError.duplicatedBatch)
                        }
                        return
                    }
                    batchChecked = true
                }
                insertedItems += 1
                self.insertImageItemData(data: imageData, context: context)
            }
            self.saveContext(context: context)
            self.viewContext.perform {
                completion(true, insertedItems, nil)
            }
        }
        
    }

    func checkIfValidImageData(data: [String: Any]) -> Bool {
        guard let _ = data[JSONKey.title] as? String else {
            return false
        }
        guard let _ = data[JSONKey.id] as? String else {
            return false
        }
        guard let _ = data[JSONKey.datetime] as? TimeInterval else {
            return false
        }
        guard let _ = data[JSONKey.views] as? Int64 else {
            return false
        }
        guard let _ = data[JSONKey.link] as? String else {
            return false
        }
        
        guard let type = data[JSONKey.type] as? String else {
            return false
        }
        
        if type != "image/jpeg" && type != "image/png" {
            return false
        }
        
        return true
    }
}
