package com.shopweb.service.manager;

import com.shopweb.dto.ProductAttributeDTO;
import com.shopweb.dto.ProductRequest;
import com.shopweb.model.entity.Category;
import com.shopweb.model.entity.Product;
import com.shopweb.model.entity.ProductAttribute;
import com.shopweb.repository.CategoryRepository;
import com.shopweb.repository.ProductAttributeRepository;
import com.shopweb.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class ManagerProductService {

    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private CategoryRepository categoryRepository;
    @Autowired
    private ProductAttributeRepository attributeRepository;

    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    public List<Product> getLowStockProducts() {
        return productRepository.findLowStockProducts();
    }

    @Transactional
    public Product createProduct(ProductRequest request) {
        Product product = new Product();
        mapRequestToEntity(request, product);
        product.setCreatedAt(LocalDateTime.now());

        Product savedProduct = productRepository.save(product);
        saveAttributes(savedProduct, request.getAttributes());
        return savedProduct;
    }

    @Transactional
    public Product updateProduct(Long id, ProductRequest request) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));

        mapRequestToEntity(request, product);
        product.setUpdatedAt(LocalDateTime.now());

        attributeRepository.deleteByProduct(product);
        saveAttributes(product, request.getAttributes());

        return productRepository.save(product);
    }

    @Transactional
    public void deleteProduct(Long id) {
        Product product = productRepository.findById(id).orElseThrow();
        attributeRepository.deleteByProduct(product);
        productRepository.delete(product);
    }

    /**
     * Map request data to Product entity — handles multiple categories
     */
    private void mapRequestToEntity(ProductRequest request, Product product) {
        product.setName(request.getName());
        product.setDescription(request.getDescription());
        product.setPrice(request.getPrice());
        product.setBrand(request.getBrand());
        product.setImageUrl(request.getImageUrl());
        product.setStockQuantity(request.getStockQuantity());
        product.setIsActive(true);

        // Validate and set min stock level
        if (request.getMinStockLevel() != null) {
            if (request.getMinStockLevel() < 0) {
                throw new IllegalArgumentException("Min stock level must not be negative");
            }
            product.setMinStock(request.getMinStockLevel());
        } else {
            product.setMinStock(0);
        }

        // Handle multiple categories
        if (request.getCategoryIds() != null && !request.getCategoryIds().isEmpty()) {
            List<Category> categories = categoryRepository.findAllById(request.getCategoryIds());
            product.setCategories(categories);
        } else {
            product.setCategories(new ArrayList<>());
        }
    }

    private void saveAttributes(Product product, List<ProductAttributeDTO> attributeDTOs) {
        if (attributeDTOs != null && !attributeDTOs.isEmpty()) {
            List<ProductAttribute> attributes = new ArrayList<>();
            for (ProductAttributeDTO dto : attributeDTOs) {
                ProductAttribute attr = new ProductAttribute();
                attr.setProduct(product);
                attr.setAttributeName(dto.getName());
                attr.setAttributeValue(dto.getValue());
                attributes.add(attr);
            }
            attributeRepository.saveAll(attributes);
        }
    }
}