import SwiftUI

// MARK: - Keyboard Dismiss Extension
extension View {
    /// Adds a "Done" button to the keyboard toolbar to dismiss the keyboard
    func keyboardDismissToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    hideKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Dismiss keyboard")
            }
        }
    }
    
    /// Hides the keyboard by ending editing on the current window
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Global Keyboard Dismiss Modifier
/// A view modifier that can be applied at the app level to enable tap-to-dismiss
struct TapToDismissKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                hideKeyboard()
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Allows tapping anywhere on the view to dismiss the keyboard
    func tapToDismissKeyboard() -> some View {
        modifier(TapToDismissKeyboard())
    }
}
