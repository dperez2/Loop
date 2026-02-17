//
//  LiveActivityBottomRowManagerView.swift
//  Loop
//
//  Created by Bastiaan Verhaar on 06/07/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import LoopCore
import SwiftUI

struct LiveActivityBottomRowManagerView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    // The maximum items in the bottom row
    private let maxSize = 4
    
    @State var showAdd: Bool = false
    @State var configuration: [BottomRowConfiguration]
    @State private var previousConfiguration: [BottomRowConfiguration]
    @State private var isDirty = false
    
    init() {
        configuration = (UserDefaults.standard.liveActivity ?? LiveActivitySettings()).bottomRowConfiguration
        previousConfiguration = (UserDefaults.standard.liveActivity ?? LiveActivitySettings()).bottomRowConfiguration
    }
    
    
    var body: some View {
        List {
            Section(header: Text("Display up to 4 items. Display label is in parentheses.", comment: "Indicates the maximum number of items that can be displayed and how the label for each item is shortened.")) {
                ForEach($configuration, id: \.self) { item in
                    HStack {
                        deleteButton
                            .onTapGesture {
                                onDelete(item.wrappedValue)
                                isDirty = configuration != previousConfiguration
                            }
                        Text(item.wrappedValue.description())
                        Spacer()
                        editBars
                    }
                }
                .onMove(perform: onReorder)
                .deleteDisabled(true)
            }
            
            Section {
                Button(action: onSave) {
                    Text(NSLocalizedString("Save", comment: ""))
                }
                .disabled(!isDirty)
                .buttonStyle(ActionButtonStyle())
                .listRowInsets(EdgeInsets())
            }
        }
        .onAppear {
            configuration = (UserDefaults.standard.liveActivity ?? LiveActivitySettings()).bottomRowConfiguration
            previousConfiguration = (UserDefaults.standard.liveActivity ?? LiveActivitySettings()).bottomRowConfiguration
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(
                    action: { showAdd = true },
                    label: { Image(systemName: "plus") }
                )
                .disabled(configuration.count >= self.maxSize)
            }
        }
        .confirmationDialog(NSLocalizedString("Add item to Lock Screen / CarPlay display", comment: "Title for Add item"), isPresented: $showAdd, titleVisibility: .visible) {
            ForEach(BottomRowConfiguration.all, id: \.self) { item in
                Button(item.description()) {
                    configuration.append(item)
                    isDirty = configuration != previousConfiguration
                }
            }
            Button(NSLocalizedString("Cancel", comment: "Button text to cancel"), role: .cancel) {
                showAdd = false
            }
        }
        .insetGroupedListStyle()
        .navigationBarTitle(Text(NSLocalizedString("Configure Display", comment: "Title for the view to configure the lock screen display")))
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        ZStack {
            Color.red
                .clipShape(RoundedRectangle(cornerRadius: 12.5))
                .frame(width: 20, height: 20)
            
            Image(systemName: "minus")
                .foregroundColor(.white)
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var editBars: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundColor(Color(UIColor.tertiaryLabel))
            .font(.title2)
    }
    
    private func onSave() {
        var settings = UserDefaults.standard.liveActivity ?? LiveActivitySettings()
        settings.bottomRowConfiguration = configuration
        
        UserDefaults.standard.liveActivity = settings
        NotificationCenter.default.post(name: .LiveActivitySettingsChanged, object: settings)
        
        self.presentationMode.wrappedValue.dismiss()
    }
    
    func onReorder(from: IndexSet, to: Int) {
        withAnimation {
            configuration.move(fromOffsets: from, toOffset: to)
            isDirty = configuration != previousConfiguration
        }
    }
    
    func onDelete(_ item: BottomRowConfiguration) {
        withAnimation {
            _ = configuration.remove(item)
        }
    }
}

#Preview {
    LiveActivityBottomRowManagerView()
}
