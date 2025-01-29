package finos.traderx.tradeprocessor.model;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Converter to (de)serialize trade side class
 * for json mapping
 **/
@Converter
public class TradeSideConverter
  extends ScalaCaseConverter<traderx.morphir.rulesengine.models.TradeSide.TradeSide> {

}
