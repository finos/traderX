package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.Error
*/
object Error{

  final case class ErrResponse(
    code: morphir.sdk.Basics.Int,
    msg: morphir.sdk.String.String
  ){}
  
  sealed trait Errors[Err] {
  
    
  
  }
  
  object Errors{
  
    final case class CancelTradeError[Err](
      arg1: traderx.morphir.rulesengine.models.Error.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Error.Errors[Err]{}
    
    final case class INVALIDACCOUNT[Err](
      arg1: traderx.morphir.rulesengine.models.Error.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Error.Errors[Err]{}
    
    final case class INVALIDTRADESIDE[Err](
      arg1: traderx.morphir.rulesengine.models.Error.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Error.Errors[Err]{}
    
    final case class INVALIDTRADESTATE[Err](
      arg1: traderx.morphir.rulesengine.models.Error.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Error.Errors[Err]{}
  
  }
  
  val CancelTradeError: traderx.morphir.rulesengine.models.Error.Errors.CancelTradeError.type  = traderx.morphir.rulesengine.models.Error.Errors.CancelTradeError
  
  val INVALIDACCOUNT: traderx.morphir.rulesengine.models.Error.Errors.INVALIDACCOUNT.type  = traderx.morphir.rulesengine.models.Error.Errors.INVALIDACCOUNT
  
  val INVALIDTRADESIDE: traderx.morphir.rulesengine.models.Error.Errors.INVALIDTRADESIDE.type  = traderx.morphir.rulesengine.models.Error.Errors.INVALIDTRADESIDE
  
  val INVALIDTRADESTATE: traderx.morphir.rulesengine.models.Error.Errors.INVALIDTRADESTATE.type  = traderx.morphir.rulesengine.models.Error.Errors.INVALIDTRADESTATE

}