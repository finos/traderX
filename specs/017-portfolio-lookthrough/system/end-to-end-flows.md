# End To End Flows

Seed synthetic reference data and trading positions once → snapshot current source → normalize holdings → build SQL/graph projection → calculate aggregate exposure → expand explanation paths. Source edits repeat the projection cycle; errors disable successful reads until recovery.
