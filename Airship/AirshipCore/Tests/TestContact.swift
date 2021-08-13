import Foundation

@testable
import AirshipCore

@objc(UATestContact)
public class TestContact : NSObject, ContactProtocol {
    public var namedUserID: String?
    
    public var pendingAttributeUpdates: [AttributeUpdate] = []
    
    public var pendingTagGroupUpdates: [TagGroupUpdate] = []
    
    @objc
    public var tagGroupEditor : TagGroupsEditor?
    
    @objc
    public var attributeEditor : AttributesEditor?
    
    public func identify(_ namedUserID: String) {
        self.namedUserID = namedUserID
    }
    
    public func reset() {
        self.namedUserID = nil
    }
    
    public func editTagGroups() -> TagGroupsEditor {
        return tagGroupEditor!
    }
    
    public func editAttributes() -> AttributesEditor {
        return attributeEditor!
    }
    
    
}
