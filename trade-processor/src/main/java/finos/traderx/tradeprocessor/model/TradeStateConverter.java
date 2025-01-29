package finos.traderx.tradeprocessor.model;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Converter to (de)serialize trade state class
 * for json mapping
 **/
@Converter
public class TradeStateConverter extends
  ScalaCaseConverter<traderx.morphir.rulesengine.models.TradeState.TradeState> {
}
