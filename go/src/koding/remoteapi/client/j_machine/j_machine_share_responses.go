package j_machine

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the swagger generate command

import (
	"fmt"
	"io"

	"github.com/go-openapi/errors"
	"github.com/go-openapi/runtime"
	"github.com/go-openapi/swag"

	strfmt "github.com/go-openapi/strfmt"

	"koding/remoteapi/models"
)

// JMachineShareReader is a Reader for the JMachineShare structure.
type JMachineShareReader struct {
	formats strfmt.Registry
}

// ReadResponse reads a server response into the received o.
func (o *JMachineShareReader) ReadResponse(response runtime.ClientResponse, consumer runtime.Consumer) (interface{}, error) {
	switch response.Code() {

	case 200:
		result := NewJMachineShareOK()
		if err := result.readResponse(response, consumer, o.formats); err != nil {
			return nil, err
		}
		return result, nil

	default:
		return nil, runtime.NewAPIError("unknown error", response, response.Code())
	}
}

// NewJMachineShareOK creates a JMachineShareOK with default headers values
func NewJMachineShareOK() *JMachineShareOK {
	return &JMachineShareOK{}
}

/*JMachineShareOK handles this case with default header values.

OK
*/
type JMachineShareOK struct {
	Payload JMachineShareOKBody
}

func (o *JMachineShareOK) Error() string {
	return fmt.Sprintf("[POST /remote.api/JMachine.share/{id}][%d] jMachineShareOK  %+v", 200, o.Payload)
}

func (o *JMachineShareOK) readResponse(response runtime.ClientResponse, consumer runtime.Consumer, formats strfmt.Registry) error {

	// response payload
	if err := consumer.Consume(response.Body(), &o.Payload); err != nil && err != io.EOF {
		return err
	}

	return nil
}

/*JMachineShareOKBody j machine share o k body
swagger:model JMachineShareOKBody
*/
type JMachineShareOKBody struct {
	models.JMachine

	models.DefaultResponse
}

// UnmarshalJSON unmarshals this object from a JSON structure
func (o *JMachineShareOKBody) UnmarshalJSON(raw []byte) error {

	var jMachineShareOKBodyAO0 models.JMachine
	if err := swag.ReadJSON(raw, &jMachineShareOKBodyAO0); err != nil {
		return err
	}
	o.JMachine = jMachineShareOKBodyAO0

	var jMachineShareOKBodyAO1 models.DefaultResponse
	if err := swag.ReadJSON(raw, &jMachineShareOKBodyAO1); err != nil {
		return err
	}
	o.DefaultResponse = jMachineShareOKBodyAO1

	return nil
}

// MarshalJSON marshals this object to a JSON structure
func (o JMachineShareOKBody) MarshalJSON() ([]byte, error) {
	var _parts [][]byte

	jMachineShareOKBodyAO0, err := swag.WriteJSON(o.JMachine)
	if err != nil {
		return nil, err
	}
	_parts = append(_parts, jMachineShareOKBodyAO0)

	jMachineShareOKBodyAO1, err := swag.WriteJSON(o.DefaultResponse)
	if err != nil {
		return nil, err
	}
	_parts = append(_parts, jMachineShareOKBodyAO1)

	return swag.ConcatJSON(_parts...), nil
}

// Validate validates this j machine share o k body
func (o *JMachineShareOKBody) Validate(formats strfmt.Registry) error {
	var res []error

	if err := o.JMachine.Validate(formats); err != nil {
		res = append(res, err)
	}

	if err := o.DefaultResponse.Validate(formats); err != nil {
		res = append(res, err)
	}

	if len(res) > 0 {
		return errors.CompositeValidationError(res...)
	}
	return nil
}
