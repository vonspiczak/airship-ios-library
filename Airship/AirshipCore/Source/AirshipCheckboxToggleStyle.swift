/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipCheckboxToggleStyle: ToggleStyle {
    let viewConstraints: ViewConstraints
    let model: CheckboxToggleStyleModel
    let colorScheme: ColorScheme
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn
        let binding = isOn ? model.bindings.selected : model.bindings.unselected
        
        return Button(action: { configuration.isOn.toggle() } ) {
            ZStack {
                if let shapes = binding.shapes {
                    ForEach(0..<shapes.count, id: \.self) { index in
                        Shapes.shape(model: shapes[index], colorScheme: colorScheme)
                    }
                }
                
                if let iconModel = binding.icon {
                    Icons.icon(model: iconModel, colorScheme: colorScheme)
                }
            }
            .frame(width: viewConstraints.width ?? 24,
                    height: viewConstraints.height ?? 24,
                    alignment: .center)
                .animation(Animation.easeInOut(duration: 0.05))
        }
    }
}