package finos.traderx.tradeprocessor.model;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Converter to (de)serialize trade state class
 * for json mapping
 **/
@Converter
public class TradeStateConverter implements AttributeConverter<
    traderx.morphir.rulesengine.models.TradeState.TradeState, String> {

  @Override
  public String convertToDatabaseColumn(
      traderx.morphir.rulesengine.models.TradeState.TradeState object) {
    return object.getClass().getName();
  }

  @Override
  public traderx.morphir.rulesengine.models.TradeState.TradeState
  convertToEntityAttribute(String json) {
    try {
      return (traderx.morphir.rulesengine.models.TradeState.TradeState)Class
          .forName(json)
          .getDeclaredConstructor()
          .newInstance();
    } catch (Exception e) {
      return null;
    }
  }
}
