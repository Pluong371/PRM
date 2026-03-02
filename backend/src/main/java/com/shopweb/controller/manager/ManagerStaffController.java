package com.shopweb.controller.manager;

import org.springframework.web.bind.annotation.*;

/**
 * Controller for manager staff coordination
 */
@RestController
@RequestMapping("/api/manager/staff")
public class ManagerStaffController {
    
    // GET /api/manager/staff - Get all staff
    // POST /api/manager/staff/assignments - Assign task to staff
    // GET /api/manager/staff/{id}/tasks - Get staff tasks
    // PUT /api/manager/staff/assignments/{id} - Update assignment
}
