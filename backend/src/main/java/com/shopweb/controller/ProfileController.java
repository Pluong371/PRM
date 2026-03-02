package com.shopweb.controller;

import com.shopweb.model.entity.dto.ChangePasswordRequest;
import com.shopweb.model.entity.dto.ProfileResponse;
import com.shopweb.model.entity.dto.UpdateProfileRequest;
import com.shopweb.service.user.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/profile")
public class ProfileController {

    private final UserService userService;

    @Autowired
    public ProfileController(UserService userService) {
        this.userService = userService;
    }

    // Xem profile
    @GetMapping
    @PreAuthorize("hasAnyRole('USER','CUSTOMER')")
    public ResponseEntity<ProfileResponse> getProfile(@AuthenticationPrincipal UserDetails userDetails) {


        ProfileResponse response = userService.getProfile(userDetails.getUsername());





        return ResponseEntity.ok(response);

    }

    // Cập nhật profile
    @PutMapping("/update")
    @PreAuthorize("hasAnyRole('USER','CUSTOMER')")
    public ResponseEntity<String> updateProfile(@AuthenticationPrincipal UserDetails userDetails,
                                                @RequestBody UpdateProfileRequest request) {
        userService.updateProfile(userDetails.getUsername(), request);
        return ResponseEntity.ok("Profile updated successfully");
    }

    // Đổi mật khẩu
    @PutMapping("/change-password")
    @PreAuthorize("hasAnyRole('USER','CUSTOMER')")
    public ResponseEntity<String> changePassword(@AuthenticationPrincipal UserDetails userDetails,
                                                 @RequestBody ChangePasswordRequest request) {
        userService.changePassword(userDetails.getUsername(), request);
        return ResponseEntity.ok("Password changed successfully");
    }
}