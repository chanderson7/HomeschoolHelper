import SwiftUI
import HomeschoolAuth

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    var recoveringPassword = false
    @State private var creatingAccount = false
    @State private var selectedLegalDocument: LegalDocumentType?
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @FocusState private var field: Field?
    private enum Field { case email, password, confirmation }

    private var title: String {
        recoveringPassword ? "Choose a new password" : creatingAccount ? "Start your family’s journey" : "Welcome back"
    }
    private var needsConfirmation: Bool { recoveringPassword || creatingAccount }
    private var valid: Bool {
        let emailValid = email.contains("@") && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (recoveringPassword || emailValid) && !password.isEmpty
            && (!needsConfirmation || (password.count >= 8 && password == confirmation))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 54)).foregroundStyle(Sage.accent).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Homeschool Compass").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text(title).font(.largeTitle.bold())
                        Text(recoveringPassword ? "Set a password with at least 8 characters." : "A little structure. More room to learn together.")
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        if !recoveringPassword {
                            VStack(alignment: .leading) {
                                Text("Email").font(.subheadline.weight(.semibold))
                                TextField("you@example.com", text: $email)
                                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($field, equals: .email).submitLabel(.next)
                                    .onSubmit { field = .password }
                                    .accessibilityIdentifier("loginEmail")
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Password").font(.subheadline.weight(.semibold))
                            SecureField("Password", text: $password)
                                .textContentType(needsConfirmation ? .newPassword : .password)
                                .focused($field, equals: .password)
                                .accessibilityIdentifier("loginPassword")
                        }
                        if needsConfirmation {
                            VStack(alignment: .leading) {
                                Text("Confirm password").font(.subheadline.weight(.semibold))
                                SecureField("Repeat password", text: $confirmation)
                                    .textContentType(.newPassword).focused($field, equals: .confirmation)
                                    .accessibilityIdentifier("loginPasswordConfirmation")
                            }
                            if creatingAccount { Text("Use at least 8 characters. We’ll email you a confirmation link.").font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    if let error = auth.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                            .accessibilityIdentifier("authError")
                    }
                    if let notice = auth.notice {
                        Label(notice, systemImage: "envelope").foregroundStyle(.secondary)
                            .accessibilityIdentifier("authNotice")
                    }
                    Button {
                        field = nil
                        Task {
                            if recoveringPassword { await auth.updatePassword(password: password) }
                            else if creatingAccount { await auth.signUp(email: email, password: password) }
                            else { await auth.signIn(email: email, password: password) }
                            password = ""; confirmation = ""
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if auth.isBusy { ProgressView() }
                            Text(recoveringPassword ? "Save password" : creatingAccount ? "Create account" : "Sign in")
                            Spacer()
                        }.padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent).disabled(!valid || auth.isBusy)
                    .accessibilityIdentifier("loginSubmit")

                    if !recoveringPassword {
                        Button(creatingAccount ? "Already have an account? Sign in" : "New here? Create an account") {
                            creatingAccount.toggle(); password = ""; confirmation = ""
                            auth.clearMessages()
                        }.disabled(auth.isBusy).accessibilityIdentifier("loginToggleMode")
                        Button("Forgot your password?") {
                            field = nil
                            Task { await auth.sendPasswordReset(email: email) }
                        }.disabled(!email.contains("@") || auth.isBusy)
                            .accessibilityIdentifier("loginResetPassword")
                        Button("Retry saved session") { Task { await auth.refreshSession() } }
                            .font(.footnote).disabled(auth.isBusy)
                    } else {
                        Button("Cancel and sign out") { Task { await auth.signOut() } }
                    }
                    VStack(spacing: 8) {
                        Text("Your family’s records are available only after you sign in.")
                            .font(.footnote).foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Button("Terms of Service") {
                                selectedLegalDocument = .termsOfService
                            }
                            .accessibilityIdentifier("loginTermsLink")

                            Text("•").foregroundStyle(.secondary)

                            Button("Privacy Policy") {
                                selectedLegalDocument = .privacyPolicy
                            }
                            .accessibilityIdentifier("loginPrivacyLink")
                        }
                        .font(.caption)
                    }
                }
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(Sage.background).scrollDismissesKeyboard(.interactively)
            .sheet(item: $selectedLegalDocument) { docType in
                LegalDocumentView(documentType: docType)
            }
            .accessibilityIdentifier("loginScreen")
        }
    }
}
