package com.shopweb.controller.customer;

import com.shopweb.model.entity.Product;
import com.shopweb.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Controller for customer product browsing
 */
@RestController
@RequestMapping("/api/customer/products")
public class CustomerProductController {

    @Autowired
    private ProductRepository productRepository;

    // GET /api/customer/products - List all products with filtering
    @GetMapping
    public ResponseEntity<List<Product>> getAllProducts(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) List<Long> categoryIds,
            @RequestParam(required = false) BigDecimal minPrice,
            @RequestParam(required = false) BigDecimal maxPrice,
            @RequestParam(required = false) List<String> brands,
            @RequestParam Map<String, String> allParams) {
        // Extract attribute params.
        java.util.Map<String, String> attributeFilters = new java.util.HashMap<>();
        for (Map.Entry<String, String> entry : allParams.entrySet()) {
            if (entry.getKey().startsWith("attr_")) {
                attributeFilters.put(entry.getKey().substring(5), entry.getValue());
            }
        }

        org.springframework.data.jpa.domain.Specification<Product> spec = com.shopweb.repository.specification.ProductSpecification
                .getProducts(search, categoryIds, minPrice, maxPrice, brands, attributeFilters);

        return ResponseEntity.ok(productRepository.findAll(spec));
    }

    @Autowired
    private com.shopweb.repository.CategoryRepository categoryRepository;

    // GET /api/customer/products/categories - List all categories
    @GetMapping("/categories")
    public ResponseEntity<List<com.shopweb.model.entity.Category>> getCategories() {
        System.out.println("chạy tới đây");
        return ResponseEntity.ok(categoryRepository.findAll());
    }

    // GET /api/customer/products/brands - List all brands
    @GetMapping("/brands")
    public ResponseEntity<List<String>> getBrands() {
        return ResponseEntity.ok(productRepository.findDistinctBrands());
    }

    // GET /api/customer/products/{id} - Get product details
    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable Long id) {
        return productRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
