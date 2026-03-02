package com.shopweb.service.user;

import com.shopweb.model.entity.dto.ChangePasswordRequest;
import com.shopweb.model.entity.dto.ProfileResponse;
import com.shopweb.model.entity.dto.UpdateProfileRequest;
import com.shopweb.model.entity.User;
import com.shopweb.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Autowired
    public UserService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * Lấy thông tin profile của người dùng hiện tại
     */
    public ProfileResponse getProfile(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        ProfileResponse response = new ProfileResponse();
        response.setUsername(user.getUsername());
        response.setFullName(user.getFullName());
        response.setEmail(user.getEmail());
        response.setPhoneNumber(user.getPhoneNumber());
        return response;
    }

    /**
     * Cập nhật thông tin profile
     */
    public void updateProfile(String username, UpdateProfileRequest request) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        boolean emailChanged = request.getEmail() != null
                && !request.getEmail().equals(user.getEmail());

        boolean phoneChanged = request.getPhoneNumber() != null
                && !request.getPhoneNumber().equals(user.getPhoneNumber());

        if (emailChanged || phoneChanged) {

            if (request.getPassword() == null || request.getPassword().isBlank()) {
                throw new RuntimeException("Phải nhập mật khẩu để xác nhận thay đổi");
            }

            if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
                throw new RuntimeException("Mật khẩu không đúng");
            }
        }

        user.setFullName(request.getFullName());
        user.setEmail(request.getEmail());
        user.setPhoneNumber(request.getPhoneNumber());

        userRepository.save(user);
    }

    /**
     * Đổi mật khẩu
     */
    public void changePassword(String username, ChangePasswordRequest request) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 1. Check mật khẩu cũ
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new RuntimeException("Old password is incorrect");
        }

        // 2. Check newPassword == confirmPassword
        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            throw new RuntimeException("New password and confirm password do not match");
        }

        // 3. Encode và lưu
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }
}