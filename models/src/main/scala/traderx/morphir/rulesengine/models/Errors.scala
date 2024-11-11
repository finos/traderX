package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.Errors
*/
object Errors{

  final case class ErrResponse(
    code: morphir.sdk.Basics.Int,
    msg: morphir.sdk.String.String
  ){}
  
  sealed trait Errors[Err] {
  
    
  
  }
  
  object Errors{
  
    final case class CancelTradeError[Err](
      arg1: traderx.morphir.rulesengine.models.Errors.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Errors.Errors[Err]{}
    
    final case class INVALIDACCOUNT[Err](
      arg1: traderx.morphir.rulesengine.models.Errors.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Errors.Errors[Err]{}
    
    final case class INVALIDTRADESIDE[Err](
      arg1: traderx.morphir.rulesengine.models.Errors.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Errors.Errors[Err]{}
    
    final case class INVALIDTRADESTATE[Err](
      arg1: traderx.morphir.rulesengine.models.Errors.ErrResponse
    ) extends traderx.morphir.rulesengine.models.Errors.Errors[Err]{}
  
  }
  
  val CancelTradeError: traderx.morphir.rulesengine.models.Errors.Errors.CancelTradeError.type  = traderx.morphir.rulesengine.models.Errors.Errors.CancelTradeError
  
  val INVALIDACCOUNT: traderx.morphir.rulesengine.models.Errors.Errors.INVALIDACCOUNT.type  = traderx.morphir.rulesengine.models.Errors.Errors.INVALIDACCOUNT
  
  val INVALIDTRADESIDE: traderx.morphir.rulesengine.models.Errors.Errors.INVALIDTRADESIDE.type  = traderx.morphir.rulesengine.models.Errors.Errors.INVALIDTRADESIDE
  
  val INVALIDTRADESTATE: traderx.morphir.rulesengine.models.Errors.Errors.INVALIDTRADESTATE.type  = traderx.morphir.rulesengine.models.Errors.Errors.INVALIDTRADESTATE

}