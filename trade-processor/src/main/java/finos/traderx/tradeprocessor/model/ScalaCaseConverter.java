package finos.traderx.tradeprocessor.model;

import jakarta.persistence.AttributeConverter;

public class ScalaCaseConverter<T> implements AttributeConverter<T, String> {

  @Override
  public String convertToDatabaseColumn(T object) {
    return object.getClass().getName();
  }

  @Override
  public T convertToEntityAttribute(String json) {
    try {
      return (T)Class.forName(json).getDeclaredConstructor().newInstance();
    } catch (Exception e) {
      return null;
    }
  }
}
