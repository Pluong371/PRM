package com.shopweb.controller.admin;

import com.shopweb.dto.request.UserRequest;
import com.shopweb.dto.response.UserResponse;
import com.shopweb.service.admin.AdminUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Controller for admin user management
 */
@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    @Autowired
    private AdminUserService adminUserService;

    @GetMapping
    public ResponseEntity<List<UserResponse>> getAllUsers() {
        return ResponseEntity.ok(adminUserService.getAllUsers());
    }

    @PostMapping
    public ResponseEntity<UserResponse> createUser(@RequestBody UserRequest request) {
        return ResponseEntity.ok(adminUserService.createUser(request));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUserById(@PathVariable Long id) {
        return ResponseEntity.ok(adminUserService.getUserById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> updateUser(@PathVariable Long id, @RequestBody UserRequest request) {
        return ResponseEntity.ok(adminUserService.updateUser(id, request));
    }

    @PutMapping("/{id}/lock")
    public ResponseEntity<Void> lockUser(@PathVariable Long id) {
        adminUserService.lockUser(id);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/{id}/unlock")
    public ResponseEntity<Void> unlockUser(@PathVariable Long id) {
        adminUserService.unlockUser(id);
        return ResponseEntity.ok().build();
    }
}
