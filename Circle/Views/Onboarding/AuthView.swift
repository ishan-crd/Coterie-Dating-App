//
//  AuthView.swift
//  Circle
//
//  The doorway to Circle: sign in with Apple, Google or phone. A quiet,
//  editorial welcome — pulsing rings, drifting interest chips, serif wordmark.
//

import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    @EnvironmentObject var app: AppState
    @State private var appeared = false
    @State private var showPhoneSheet = false
    @State private var appleCoordinator = AppleSignInCoordinator()

    var body: some View {
        ZStack {
            CT.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Illustration: pulsing rings with drifting interest chips
                ZStack {
                    PulseRings(color: CT.accent, size: 150)
                    FloatingChip(text: "Hiking",  x: -104, y: -66, delay: 0.0)
                    FloatingChip(text: "Music",   x: 108,  y: -38, delay: 0.7)
                    FloatingChip(text: "Film",    x: -86,  y: 62,  delay: 1.3)
                    FloatingChip(text: "Coffee",  x: 92,   y: 78,  delay: 1.9)
                }
                .frame(height: 230)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.9).delay(0.1), value: appeared)

                // Wordmark + tagline
                VStack(spacing: 14) {
                    LogoMark(height: 52)
                    Text("Find friends who share your world.")
                        .serifItalic(19)
                        .foregroundStyle(CT.bodyLight)
                }
                .padding(.top, 26)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.easeOut(duration: 0.8).delay(0.35), value: appeared)

                Spacer()

                // Sign-in options — one shared style, one size, one text size
                VStack(spacing: 12) {
                    providerButton(label: "Continue with Apple") {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(CT.ink)
                    } action: {
                        startAppleSignIn()
                    }
                    providerButton(label: "Continue with Google") {
                        Image("google-logo").resizable().scaledToFit()
                    } action: {
                        app.signInWithGoogle()
                    }
                    providerButton(label: "Continue with Phone") {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CT.ink)
                    } action: {
                        showPhoneSheet = true
                    }
                }
                .padding(.horizontal, 30)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.55), value: appeared)

                if let error = app.authError {
                    Text(error)
                        .font(.grotesk(12)).foregroundStyle(CT.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14).padding(.horizontal, 40)
                        .transition(.opacity)
                }

                Text("By continuing you agree to be kind.")
                    .font(.grotesk(11)).tracking(0.4)
                    .foregroundStyle(CT.faint)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.75), value: appeared)
            }

            if app.authBusy {
                ZStack {
                    CT.paper.opacity(0.6).ignoresSafeArea()
                    ProgressView().tint(CT.accent).scaleEffect(1.2)
                }
                .transition(.opacity)
            }
        }
        .onAppear { appeared = true }
        .sheet(isPresented: $showPhoneSheet) { PhoneAuthSheet() }
        .animation(.easeOut(duration: 0.25), value: app.authBusy)
        .animation(.easeOut(duration: 0.25), value: app.authError)
    }

    // MARK: Apple (native flow, custom chrome)

    private func startAppleSignIn() {
        let nonce = AppleNonce.generate()
        app.appleNonce = nonce
        appleCoordinator.onResult = { result in app.handleAppleSignIn(result) }
        appleCoordinator.start(nonce: nonce)
    }

    // MARK: Shared button chrome — identical size, font and icon slot

    private func providerButton<Icon: View>(
        label: String,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon().frame(width: 20, height: 20)
                Text(label).font(.grotesk(15, weight: .medium)).tracking(0.3)
                    .foregroundStyle(CT.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(CT.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CT.borderStrong, lineWidth: 1))
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}

// MARK: - Apple sign-in coordinator (custom-styled button)

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {
    var onResult: ((Result<ASAuthorization, Error>) -> Void)?

    func start(nonce: String) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]
        request.nonce = AppleNonce.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        onResult?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        onResult?(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Floating interest chip (illustration ornament)

private struct FloatingChip: View {
    var text: String
    var x: CGFloat
    var y: CGFloat
    var delay: Double
    @State private var drift = false

    var body: some View {
        Text(text)
            .font(.grotesk(11, weight: .medium)).tracking(1.2).textCase(.uppercase)
            .foregroundStyle(CT.accent)
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(CT.accentSoft)
            .clipShape(Capsule())
            .offset(x: x, y: y + (drift ? -7 : 7))
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(delay),
                       value: drift)
            .onAppear { drift = true }
    }
}

// MARK: - Phone auth sheet (number → code)

private struct PhoneAuthSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(codeSent ? "Enter the code" : "Your phone number")
                    .font(.serif(30))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(CT.muted)
                        .frame(width: 32, height: 32).background(CT.fill).clipShape(Circle())
                }
            }
            .padding(.top, 28)

            Text(codeSent
                 ? "We texted a 6-digit code to \(phone)."
                 : "Include your country code, e.g. +91 98765 43210.")
                .font(.grotesk(14)).foregroundStyle(CT.bodyLight).lineSpacing(3)
                .padding(.top, 10)

            if codeSent {
                UnderlineField(placeholder: "123456", text: $code,
                               fontSize: 30, alignment: .leading, keyboard: .numberPad)
                    .focused($focused)
                    .padding(.top, 30)
                    .onChange(of: code) { _, v in
                        code = String(v.filter(\.isNumber).prefix(6))
                    }
            } else {
                UnderlineField(placeholder: "+91 98765 43210", text: $phone,
                               fontSize: 26, alignment: .leading, keyboard: .phonePad)
                    .focused($focused)
                    .padding(.top, 30)
            }

            if let error = app.authError {
                Text(error).font(.grotesk(12)).foregroundStyle(CT.accent)
                    .padding(.top, 14)
            }

            Spacer()

            PillButton(title: codeSent ? "Verify" : "Send Code",
                       style: .filled,
                       enabled: codeSent ? code.count == 6 : phone.count >= 8) {
                if codeSent {
                    app.verifyPhoneCode(phone: cleanedPhone, code: code) { dismiss() }
                } else {
                    app.sendPhoneCode(phone: cleanedPhone) { codeSent = true }
                }
            }
            .padding(.bottom, 20)

            if codeSent {
                Button {
                    codeSent = false; code = ""
                } label: {
                    Text("Use a different number")
                        .font(.grotesk(13)).foregroundStyle(CT.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 26)
        .background(CT.paper.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear { focused = true }
    }

    private var cleanedPhone: String {
        "+" + phone.filter(\.isNumber)
    }
}

// MARK: - Apple nonce helpers

enum AppleNonce {
    static func generate(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
