//
//  ContactSaver.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import Contacts

struct ContactSaver {

    func save(name: String, phone: String, email: String, organization: String) async -> String {
        let store = CNContactStore()

        do {
            guard try await store.requestAccess(for: .contacts) else {
                return "Contacts access denied. You can turn it on in Settings."
            }
        } catch {
            return "Could not ask for Contacts access."
        }

        let contact = CNMutableContact()
        let parts = name.split(separator: " ", omittingEmptySubsequences: true)
        contact.givenName = parts.first.map(String.init) ?? name
        contact.familyName = parts.dropFirst().joined(separator: " ")
        contact.organizationName = organization

        if !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile,
                                                   value: CNPhoneNumber(stringValue: phone))]
        }
        if !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelOther, value: email as NSString)]
        }

        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)

        do {
            try store.execute(request)
            let saved = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return saved.isEmpty ? "Saved to Contacts." : "Saved \(saved) to Contacts."
        } catch {
            return "Could not save the contact."
        }
    }
}
