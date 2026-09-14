//
//  CoreDataStack.swift
//  CosmoKitTestApp
//
//  Programmatic Core Data stack for diagnostics testing (Core Data SQL Debug
//  and Core Data Concurrency Debug).
//

import Foundation
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let persistentContainer: NSPersistentContainer

    init() {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "Note"
        entity.managedObjectClassName = "NSManagedObject"

        let textAttr = NSAttributeDescription()
        textAttr.name = "text"
        textAttr.attributeType = .stringAttributeType
        textAttr.isOptional = true

        entity.properties = [textAttr]
        model.entities = [entity]

        persistentContainer = NSPersistentContainer(name: "DiagnosticsModel", managedObjectModel: model)
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                NSLog("[CoreData] Error loading persistent store: %@", error.localizedDescription)
            }
        }
    }

    /// Insert and fetch 20 rows so Core Data SQL debug emits statement logs.
    func insertAndFetchNotes(count: Int = 20) -> Int {
        let context = persistentContainer.viewContext
        for i in 0..<count {
            let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
            note.setValue("Diagnostics Note \(i) - \(Date())", forKey: "text")
        }
        try? context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        let results = (try? context.fetch(request)) ?? []
        return results.count
    }

    /// Touches a background-context object from the main thread.
    /// Aborts with __Multithreading_Violation_AllThatIsLeftToUsIsHonor__
    /// only when -com.apple.CoreData.ConcurrencyDebug 1 is active.
    func violateConcurrency() {
        let bgContext = persistentContainer.newBackgroundContext()
        var bgNote: NSManagedObject?
        bgContext.performAndWait {
            let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: bgContext)
            note.setValue("Background context note", forKey: "text")
            try? bgContext.save()
            bgNote = note
        }
        _ = bgNote?.value(forKey: "text")
    }
}
