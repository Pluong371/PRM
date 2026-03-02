package com.shopweb.repository.specification;

import com.shopweb.model.entity.Product;
import com.shopweb.model.entity.ProductAttribute;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class ProductSpecification {

  public static Specification<Product> getProducts(
      String search,
      List<Long> categoryIds,
      BigDecimal minPrice,
      BigDecimal maxPrice,
      List<String> brands,
      Map<String, String> attributes) {
    return (root, query, criteriaBuilder) -> {
      List<Predicate> predicates = new ArrayList<>();

      // Always filter by isActive = true for customers
      predicates.add(criteriaBuilder.isTrue(root.get("isActive")));

      // Search by name or description
      if (search != null && !search.trim().isEmpty()) {
        System.out.println("this.search" + search);
        String likePattern = "%" + search.toLowerCase() + "%";
        Predicate nameLike = criteriaBuilder.like(criteriaBuilder.lower(root.get("name")), likePattern);
        Predicate descLike = criteriaBuilder.like(criteriaBuilder.lower(root.get("description")), likePattern);
        predicates.add(criteriaBuilder.or(nameLike, descLike));
      }

      // Filter by Category (ManyToMany — join the categories collection)
      if (categoryIds != null && !categoryIds.isEmpty()) {
        var categoryJoin = root.join("categories");
        predicates.add(categoryJoin.get("id").in(categoryIds));
        query.distinct(true); // avoid duplicates from the join
      }

      // Filter by Price Range
      if (minPrice != null) {

        System.out.println("Min price: " + minPrice);
        predicates.add(criteriaBuilder.greaterThanOrEqualTo(root.get("price"), minPrice));
      }
      if (maxPrice != null) {
        predicates.add(criteriaBuilder.lessThanOrEqualTo(root.get("price"), maxPrice));
      }

      // Filter by Brand (Multiple)
      if (brands != null && !brands.isEmpty()) {
        predicates.add(root.get("brand").in(brands));
      }

      // Dynamic Attribute Filtering
      if (attributes != null && !attributes.isEmpty()) {
        for (Map.Entry<String, String> entry : attributes.entrySet()) {
          String attrName = entry.getKey();
          String attrValue = entry.getValue();

          if (attrValue != null && !attrValue.isEmpty()) {

            var subquery = query.subquery(Long.class);
            var subRoot = subquery.from(ProductAttribute.class);
            subquery.select(subRoot.get("id"));
            subquery.where(
                criteriaBuilder.equal(subRoot.get("product"), root),
                criteriaBuilder.equal(subRoot.get("attributeName"), attrName),
                criteriaBuilder.equal(subRoot.get("attributeValue"), attrValue));
            predicates.add(criteriaBuilder.exists(subquery));
          }
        }
      }

      return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
    };
  }
}
