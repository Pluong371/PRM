package com.shopweb.controller.admin;

import org.springframework.web.bind.annotation.*;

/**
 * Controller for admin audit log viewing
 */
@RestController
@RequestMapping("/api/admin/audit")
public class AdminAuditController {
    
    // GET /api/admin/audit/logs - Get all audit logs
    // GET /api/admin/audit/logs/{id} - Get audit log details
    // GET /api/admin/audit/logs/user/{userId} - Get logs by user
    // GET /api/admin/audit/logs/entity/{entityType} - Get logs by entity type
}
