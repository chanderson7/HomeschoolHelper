import SwiftUI
import HomeschoolAuth

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    var recoveringPassword = false
    @State private var creatingAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var showConfirmation = false
    @State private var animateBloom = false
    @State private var sunGlowPulse = false
    @FocusState private var field: Field?
    private enum Field { case email, password, confirmation }

    private var title: String {
        if recoveringPassword {
            return "Choose a new password"
        }
        return creatingAccount ? "Start your family’s journey" : "Welcome back"
    }

    private var subtitle: String {
        if recoveringPassword {
            return "Set a password with at least 8 characters."
        }
        return creatingAccount ? "Organized lessons, peaceful days, and simple records." : "A little structure. More room to learn together."
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
                VStack(spacing: 24) {
                    // Morning Bloom Hero Section
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.orange.opacity(sunGlowPulse ? 0.24 : 0.10),
                                        Color.yellow.opacity(sunGlowPulse ? 0.14 : 0.04),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: 75
                                )
                            )
                            .frame(width: 150, height: 150)
                            .scaleEffect(sunGlowPulse ? 1.08 : 0.94)
                            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: sunGlowPulse)
                            .accessibilityHidden(true)

                        Image("LoginHeroArt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: field != nil ? 90 : 130)
                            .scaleEffect(animateBloom ? 1.0 : 0.88)
                            .opacity(animateBloom ? 1.0 : 0.0)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: field != nil)

                    // Header Text
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Sage.accent)
                            Text("EZHomeschool")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Sage.accent)
                        }

                        Text(title)
                            .font(.system(.title, design: .serif, weight: .bold))
                            .foregroundStyle(.primary)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .id("title-\(title)")

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                            .id("subtitle-\(subtitle)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Input Form Fields
                    VStack(spacing: 16) {
                        if !recoveringPassword {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.body)
                                        .foregroundStyle(field == .email ? Sage.accent : Color.secondary)
                                        .frame(width: 20)

                                    TextField("you@example.com", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($field, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit { field = .password }
                                        .accessibilityIdentifier("loginEmail")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(field == .email ? Sage.accent : Color(uiColor: .separator).opacity(0.35), lineWidth: field == .email ? 1.5 : 1)
                                )
                                .shadow(color: Sage.accent.opacity(field == .email ? 0.15 : 0), radius: 6, y: 1)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.body)
                                    .foregroundStyle(field == .password ? Sage.accent : Color.secondary)
                                    .frame(width: 20)

                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textContentType(needsConfirmation ? .newPassword : .password)
                                        .focused($field, equals: .password)
                                        .submitLabel(needsConfirmation ? .next : .go)
                                        .onSubmit {
                                            if needsConfirmation {
                                                field = .confirmation
                                            } else {
                                                submitForm()
                                            }
                                        }
                                        .accessibilityIdentifier("loginPassword")
                                } else {
                                    SecureField("Password", text: $password)
                                        .textContentType(needsConfirmation ? .newPassword : .password)
                                        .focused($field, equals: .password)
                                        .submitLabel(needsConfirmation ? .next : .go)
                                        .onSubmit {
                                            if needsConfirmation {
                                                field = .confirmation
                                            } else {
                                                submitForm()
                                            }
                                        }
                                        .accessibilityIdentifier("loginPassword")
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .symbolEffect(.bounce, value: showPassword)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(field == .password ? Sage.accent : Color(uiColor: .separator).opacity(0.35), lineWidth: field == .password ? 1.5 : 1)
                            )
                            .shadow(color: Sage.accent.opacity(field == .password ? 0.15 : 0), radius: 6, y: 1)
                        }

                        if needsConfirmation {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm password")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.body)
                                        .foregroundStyle(field == .confirmation ? Sage.accent : Color.secondary)
                                        .frame(width: 20)

                                    if showConfirmation {
                                        TextField("Repeat password", text: $confirmation)
                                            .textContentType(.newPassword)
                                            .focused($field, equals: .confirmation)
                                            .submitLabel(.go)
                                            .onSubmit { submitForm() }
                                            .accessibilityIdentifier("loginPasswordConfirmation")
                                    } else {
                                        SecureField("Repeat password", text: $confirmation)
                                            .textContentType(.newPassword)
                                            .focused($field, equals: .confirmation)
                                            .submitLabel(.go)
                                            .onSubmit { submitForm() }
                                            .accessibilityIdentifier("loginPasswordConfirmation")
                                    }

                                    Button {
                                        showConfirmation.toggle()
                                    } label: {
                                        Image(systemName: showConfirmation ? "eye.slash.fill" : "eye.fill")
                                            .symbolEffect(.bounce, value: showConfirmation)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(showConfirmation ? "Hide confirmation password" : "Show confirmation password")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(field == .confirmation ? Sage.accent : Color(uiColor: .separator).opacity(0.35), lineWidth: field == .confirmation ? 1.5 : 1)
                                )
                                .shadow(color: Sage.accent.opacity(field == .confirmation ? 0.15 : 0), radius: 6, y: 1)

                                if creatingAccount {
                                    Text("Use at least 8 characters. We’ll email you a confirmation link.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 2)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: field)

                    // Error & Notice Feedback Banners
                    if let error = auth.errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("authError")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let notice = auth.notice {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Sage.accent)
                            Text(notice)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Sage.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("authNotice")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Primary Action Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        submitForm()
                    } label: {
                        HStack(spacing: 8) {
                            if auth.isBusy {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(recoveringPassword ? "Save password" : creatingAccount ? "Create account" : "Sign in")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(valid && !auth.isBusy ? Sage.accent : Sage.accent.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(SpringScaleButtonStyle())
                    .disabled(!valid || auth.isBusy)
                    .accessibilityIdentifier("loginSubmit")

                    // Secondary Action Buttons
                    if !recoveringPassword {
                        VStack(spacing: 12) {
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    creatingAccount.toggle()
                                    password = ""
                                    confirmation = ""
                                    auth.clearMessages()
                                }
                            } label: {
                                Text(creatingAccount ? "Already have an account? Sign in" : "New here? Create an account")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Sage.accent)
                                    .padding(.vertical, 4)
                            }
                            .disabled(auth.isBusy)
                            .accessibilityIdentifier("loginToggleMode")

                            Button {
                                field = nil
                                Task { await auth.sendPasswordReset(email: email) }
                            } label: {
                                Text("Forgot your password?")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(!email.contains("@") || auth.isBusy)
                            .accessibilityIdentifier("loginResetPassword")
                        }
                    } else {
                        Button("Cancel and sign out") {
                            Task { await auth.signOut() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    // Legal & Trust Footer
                    VStack(spacing: 8) {
                        Text("Your family’s records are available only after you sign in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            Link("Terms of Service", destination: LegalLinks.termsOfService)
                                .accessibilityIdentifier("loginTermsLink")

                            Text("•")
                                .foregroundStyle(.secondary)

                            Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                                .accessibilityIdentifier("loginPrivacyLink")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Sage.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("loginScreen")
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                animateBloom = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                sunGlowPulse = true
            }
        }
    }

    private func submitForm() {
        field = nil
        Task {
            if recoveringPassword {
                await auth.updatePassword(password: password)
            } else if creatingAccount {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
            password = ""
            confirmation = ""
        }
    }
}
