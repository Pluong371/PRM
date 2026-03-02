package com.shopweb.controller;

import com.shopweb.model.entity.Role;
import com.shopweb.model.entity.User;
import com.shopweb.repository.RoleRepository;
import com.shopweb.repository.UserRepository;
import com.shopweb.security.AesUtil;
import com.shopweb.security.JwtUtils;
import com.shopweb.security.UserDetailsImpl;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

  @Autowired
  AuthenticationManager authenticationManager;

  @Autowired
  UserRepository userRepository;

  @Autowired
  RoleRepository roleRepository;

  @Autowired
  PasswordEncoder passwordEncoder;

  @Autowired
  JwtUtils jwtUtils;

  @Autowired
  com.shopweb.service.user.OtpService otpService;

  @Autowired
  AesUtil aesUtil;

  @PostMapping("/login")
  public ResponseEntity<?> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) {

    String decryptedPassword = aesUtil.decrypt(loginRequest.getPassword());
    System.out.println("Decrypted Password: " + decryptedPassword);

    try {
      Authentication authentication = authenticationManager.authenticate(
          new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), decryptedPassword));

      SecurityContextHolder.getContext().setAuthentication(authentication);
      UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();

      List<String> roles = userDetails.getAuthorities().stream()
          .map(item -> item.getAuthority())
          .collect(Collectors.toList());

      String jwt = jwtUtils.generateToken(userDetails.getUsername(), userDetails.getAuthorities());

      return ResponseEntity.ok(new JwtResponse(jwt,
          userDetails.getId(),
          userDetails.getUsername(),
          userDetails.getUsername(), // Using username as email for now if email not available in UserDetails, or
                                     // fetch email
          roles));
    } catch (org.springframework.security.core.AuthenticationException e) {
      if (e instanceof org.springframework.security.authentication.BadCredentialsException) {
        return ResponseEntity.badRequest().body(new MessageResponse("Tài khoản hoặc mật khẩu không chính xác!"));
      } else if (e instanceof org.springframework.security.authentication.DisabledException) {
        return ResponseEntity.badRequest()
            .body(new MessageResponse("Tài khoản của bạn đã bị khóa hoặc chưa được kích hoạt."));
      } else if (e instanceof org.springframework.security.authentication.LockedException) {
        return ResponseEntity.badRequest()
            .body(new MessageResponse("Tài khoản đang bị tạm khóa do nhập sai quá nhiều lần."));
      }
      return ResponseEntity.badRequest().body(new MessageResponse("Đăng nhập thất bại. Vui lòng thử lại."));
    }
  }

  @PostMapping("/register/send-otp")
  public ResponseEntity<?> sendRegistrationOtp(@RequestBody EmailRequest emailRequest) {
    if (userRepository.existsByEmail(emailRequest.getEmail())) {
      return ResponseEntity
          .badRequest()
          .body(new MessageResponse("Error: Email is already in use!"));
    }

    try {
      otpService.generateAndSendOtp(emailRequest.getEmail(), com.shopweb.model.enums.OtpPurpose.REGISTER);
      return ResponseEntity.ok(new MessageResponse("OTP sent successfully to " + emailRequest.getEmail()));
    } catch (RuntimeException e) {
      if ("RATE_LIMIT_EXCEEDED".equals(e.getMessage())) {
        return ResponseEntity.status(429).body(new MessageResponse("Too many requests. Please try again later."));
      }
      return ResponseEntity.badRequest().body(new MessageResponse("Failed to send OTP: " + e.getMessage()));
    }
  }

  @PostMapping("/register")
  public ResponseEntity<?> registerUser(@Valid @RequestBody SignupRequest signUpRequest) {
    if (userRepository.existsByUsername(signUpRequest.getUsername())) {
      return ResponseEntity
          .badRequest()
          .body(new MessageResponse("Error: Username is already taken!"));
    }

    if (userRepository.existsByEmail(signUpRequest.getEmail())) {
      return ResponseEntity
          .badRequest()
          .body(new MessageResponse("Error: Email is already in use!"));
    }

    // Verify OTP first
    try {
      otpService.verifyOtp(signUpRequest.getEmail(), signUpRequest.getOtpCode(),
          com.shopweb.model.enums.OtpPurpose.REGISTER);
    } catch (RuntimeException e) {
      String errMsg = "Invalid or expired OTP.";
      if ("MAX_ATTEMPTS_REACHED".equals(e.getMessage()))
        errMsg = "Maximum attempts reached. Please request a new OTP.";
      else if ("OTP_EXPIRED".equals(e.getMessage()))
        errMsg = "OTP has expired. Please request a new one.";
      else if ("INVALID_OTP".equals(e.getMessage()))
        errMsg = "Incorrect OTP code.";
      return ResponseEntity.badRequest().body(new MessageResponse("Error: " + errMsg));
    }

    // Create new user's account
    User user = new User();
    user.setUsername(signUpRequest.getUsername());
    user.setEmail(signUpRequest.getEmail());

    String decryptedPassword = aesUtil.decrypt(signUpRequest.getPassword());
    String hashedPassword = passwordEncoder.encode(decryptedPassword);

    System.out.println("--- [REGISTER FLOW] PASSWORD TRACE ---");
    System.out.println("1. Encrypted from Frontend (AES): " + signUpRequest.getPassword());
    System.out.println("2. Decrypted by Backend (Plain): " + decryptedPassword);
    System.out.println("3. Hashed for Database (BCrypt): " + hashedPassword);
    System.out.println("----------------------------------------");

    user.setPassword(hashedPassword);

    user.setFullName(signUpRequest.getFullName());

    Set<Role> roles = new HashSet<>();
    // Default role
    Role userRole = roleRepository.findByName("ROLE_CUSTOMER")
        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
    roles.add(userRole);

    user.setRoles(roles);
    userRepository.save(user);

    return ResponseEntity.ok(new MessageResponse("User registered successfully!"));
  }

  @PostMapping("/forgot-password/send-otp")
  public ResponseEntity<?> sendForgotPasswordOtp(@RequestBody EmailRequest emailRequest) {
    boolean exists = userRepository.existsByEmail(emailRequest.getEmail());

    if (!exists) {
      return ResponseEntity.badRequest().body(new MessageResponse("Email này chưa được đăng ký trong hệ thống!"));
    }

    try {
      otpService.generateAndSendOtp(emailRequest.getEmail(), com.shopweb.model.enums.OtpPurpose.FORGOT_PASSWORD);
      return ResponseEntity.ok(new MessageResponse("OTP đã được gửi về mail của bạn."));
    } catch (Exception e) {
      System.err.println("DEBUG FORGOT PASSWORD: OTP ERROR: " + e.getMessage());
      e.printStackTrace();
      return ResponseEntity.badRequest().body(new MessageResponse("Gửi OTP thất bại, vui lòng thử lại sau."));
    }
  }

  @PostMapping("/forgot-password/reset")
  public ResponseEntity<?> resetPassword(@Valid @RequestBody ResetPasswordRequest resetRequest) {
    try {
      // Verify OTP
      otpService.verifyOtp(resetRequest.getEmail(), resetRequest.getOtpCode(),
          com.shopweb.model.enums.OtpPurpose.FORGOT_PASSWORD);

      // Update Password
      User user = userRepository.findByEmail(resetRequest.getEmail())
          .orElseThrow(() -> new RuntimeException("User not found"));

      String decryptedPassword = aesUtil.decrypt(resetRequest.getNewPassword());
      String hashedPassword = passwordEncoder.encode(decryptedPassword);

      System.out.println("--- [RESET PASSWORD FLOW] PASSWORD TRACE ---");
      System.out.println("1. Encrypted from Frontend (AES): " + resetRequest.getNewPassword());
      System.out.println("2. Decrypted by Backend (Plain): " + decryptedPassword);
      System.out.println("3. Hashed for Database (BCrypt): " + hashedPassword);
      System.out.println("--------------------------------------------");

      user.setPassword(hashedPassword);

      userRepository.save(user);

      return ResponseEntity.ok(new MessageResponse("Password reset successfully."));
    } catch (RuntimeException e) {
      return ResponseEntity.badRequest().body(new MessageResponse("Error: Invalid or expired OTP."));
    }
  }

  // DTO classes
  @Getter
  @Setter
  public static class LoginRequest {
    @NotBlank(message = "Username cannot be blank")
    private String username;

    @NotBlank(message = "Password cannot be blank")
    private String password;
  }

  @Getter
  @Setter
  public static class SignupRequest {
    @NotBlank(message = "Username cannot be blank")
    @Size(min = 3, max = 50, message = "Username must be between 3 and 50 characters")
    @Pattern(regexp = "^[^<>]*$", message = "Username cannot contain '<' or '>' characters")
    private String username;

    @NotBlank(message = "Email cannot be blank")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Password cannot be blank")
    private String password;

    @NotBlank(message = "Full name cannot be blank")
    @Pattern(regexp = "^[^<>]*$", message = "Full name cannot contain '<' or '>' characters")
    private String fullName;

    @NotBlank(message = "OTP code is required")
    private String otpCode;
  }

  @Getter
  @Setter
  public static class EmailRequest {
    @NotBlank(message = "Email cannot be blank")
    @Email(message = "Invalid email format")
    private String email;
  }

  @Getter
  @Setter
  public static class ResetPasswordRequest {
    @NotBlank(message = "Email cannot be blank")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "OTP code is required")
    private String otpCode;

    @NotBlank(message = "New password cannot be blank")
    private String newPassword;
  }

  @Getter
  @Setter
  @AllArgsConstructor
  public static class JwtResponse {
    private String accessToken;
    private Long id;
    private String username;
    private String email;
    private List<String> roles;
  }

  @Getter
  @Setter
  @AllArgsConstructor
  public static class MessageResponse {
    private String message;
  }
}
