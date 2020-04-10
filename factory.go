package mocks

import (
	"context"

	"github.com/neuronlabs/neuron-core/mapping"
	"github.com/stretchr/testify/mock"

	"github.com/neuronlabs/neuron-core/config"
	"github.com/neuronlabs/neuron-core/repository"
)

/**

Factory

*/

// compile time check for the Factory interface implementation.
var _ repository.Factory = &Factory{}

// Factory is the repository.Factory mock implementation
type Factory struct {
	mock.Mock
}

// New creates new repository
// Implements repository.Factory method
func (f *Factory) New(model *config.Repository) (repository.Repository, error) {
	return &Repository{ids: map[*mapping.ModelStruct]string{}}, nil
}

// DriverName returns the factory repository name
// Implements repository.Repository
func (f *Factory) DriverName() string {
	return DriverName
}

// Close closes the factory
func (f *Factory) Close(ctx context.Context, done chan<- interface{}) {
	done <- struct{}{}
}
