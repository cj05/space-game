class_name OrbitalRegistry

# --- pre-initialization ----------------------------------------------------

var model: OrbitalModel

func set_model(model_in: OrbitalModel):
	model = model_in
	
# --- register functions ----------------------------------------------------

func register_body(body: AbstractBinding):
	model.insert(body) # O(1)
	
func unregister_body(body: AbstractBinding):
	model.delete(body) # O(1)
