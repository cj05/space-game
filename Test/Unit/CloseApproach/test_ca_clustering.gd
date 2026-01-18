extends GutTest

const CA_Clustering = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_Clustering.gd"
)

func test_clusters_close_brackets() -> void:
	var brackets := [
		{ "a": 100.0, "b": 110.0 },
		{ "a": 115.0, "b": 125.0 },
		{ "a": 1000.0, "b": 1010.0 }
	]
	
	var clusters := CA_Clustering.cluster_brackets(brackets, 50.0)
	
	assert_eq(clusters.size(), 2)
	assert_eq(clusters[0].brackets.size(), 2)
	assert_eq(clusters[1].brackets.size(), 1)
