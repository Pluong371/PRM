package com.shopweb.controller.manager;

import com.shopweb.dto.CategoryRequest;
import com.shopweb.model.entity.Category;
import com.shopweb.service.manager.ManagerCategoryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/manager/categories")
public class ManagerCategoryController {
    @Autowired
    private ManagerCategoryService service;

    /**
     * GET /api/manager/categories — flat list of all categories
     */
    @GetMapping
    public ResponseEntity<List<Category>> getAll() {
        return ResponseEntity.ok(service.getAllCategories());
    }

    /**
     * GET /api/manager/categories/tree — hierarchical tree (roots with nested
     * children)
     */
    @GetMapping("/tree")
    public ResponseEntity<List<Category>> getTree() {
        return ResponseEntity.ok(service.getCategoryTree());
    }

    /**
     * POST /api/manager/categories — create a new category
     */
    @PostMapping
    public ResponseEntity<Category> create(@RequestBody CategoryRequest request) {
        return ResponseEntity.ok(service.createCategory(request));
    }

    /**
     * PUT /api/manager/categories/{id} — update/rename a category
     */
    @PutMapping("/{id}")
    public ResponseEntity<Category> update(@PathVariable Long id, @RequestBody CategoryRequest request) {
        return ResponseEntity.ok(service.updateCategory(id, request));
    }

    /**
     * DELETE /api/manager/categories/{id} — delete a category and its children
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deleteCategory(id);
        return ResponseEntity.ok().build();
    }
}