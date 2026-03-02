package com.shopweb.service.manager;

import com.shopweb.dto.CategoryRequest;
import com.shopweb.model.entity.Category;
import com.shopweb.repository.CategoryRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class ManagerCategoryService {
    @Autowired
    private CategoryRepository categoryRepository;

    /**
     * Get all categories (flat list)
     */
    public List<Category> getAllCategories() {
        return categoryRepository.findAll();
    }

    /**
     * Get category tree (root categories with nested children via @OneToMany EAGER
     * fetch)
     */
    public List<Category> getCategoryTree() {
        return categoryRepository.findByParentIsNull();
    }

    /**
     * Create a new category
     */
    @Transactional
    public Category createCategory(CategoryRequest request) {
        Category category = new Category();
        category.setName(request.getName());
        category.setDescription(request.getDescription());
        category.setIsActive(request.getIsActive() != null ? request.getIsActive() : true);
        category.setCreatedAt(LocalDateTime.now());

        if (request.getParentId() != null) {
            Category parent = categoryRepository.findById(request.getParentId())
                    .orElseThrow(() -> new RuntimeException("Parent category not found"));
            category.setParent(parent);
        }

        return categoryRepository.save(category);
    }

    /**
     * Update an existing category (rename, change parent, toggle active)
     */
    @Transactional
    public Category updateCategory(Long id, CategoryRequest request) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Category not found"));

        if (request.getName() != null) {
            category.setName(request.getName());
        }
        if (request.getDescription() != null) {
            category.setDescription(request.getDescription());
        }
        if (request.getIsActive() != null) {
            category.setIsActive(request.getIsActive());
        }
        if (request.getParentId() != null) {
            // Prevent setting self as parent
            if (request.getParentId().equals(id)) {
                throw new RuntimeException("Cannot set category as its own parent");
            }
            Category parent = categoryRepository.findById(request.getParentId())
                    .orElseThrow(() -> new RuntimeException("Parent category not found"));
            category.setParent(parent);
        }

        category.setUpdatedAt(LocalDateTime.now());
        return categoryRepository.save(category);
    }

    /**
     * Delete a category by ID
     */
    @Transactional
    public void deleteCategory(Long id) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Category not found"));

        // Delete children first (cascade)
        List<Category> children = categoryRepository.findByParent_Id(id);
        for (Category child : children) {
            deleteCategory(child.getId()); // recursive delete
        }

        categoryRepository.delete(category);
    }
}