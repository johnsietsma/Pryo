#ifndef FLO_CG_INCLUDED
#define FLO_CG_INCLUDED


// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//----------------------------------------------------------------------------
// File : flo.cg
//----------------------------------------------------------------------------
// Copyright 2003 Mark J. Harris and
// The University of North Carolina at Chapel Hill
//----------------------------------------------------------------------------
// Permission to use, copy, modify, distribute and sell this software and its
// documentation for any purpose is hereby granted without fee, provided that
// the above copyright notice appear in all copies and that both that copyright
// notice and this permission notice appear in supporting documentation.
// Binaries may be compiled with this software without any royalties or
// restrictions.
//
// The author(s) and The University of North Carolina at Chapel Hill make no
// representations about the suitability of this software for any purpose.
// It is provided "as is" without express or implied warranty.

#include "floUtil.cginc" // for texRECTBilerp() and texRECTneighbors()


//----------------------------------------------------------------------------
// Function     	: advect
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program performs a semi-lagrangian advection of a passive field by
 * a moving velocity field.  It works by tracing backwards from each fragment
 * along the velocity field, and moving the passive value at its destination
 * forward to the starting point.  It performs bilinear interpolation at the
 * destination to get a smooth resulting field.
 */
float4 advect(float2      coords : WPOS,  // Pixel position
      uniform float       timestep,
      uniform float       dissipation, // mass dissipation constant.
      uniform float       rdx,         // 1 / grid scale.
      uniform sampler2D   u,           // the velocity field.
      uniform sampler2D   x)           // the field to be advected.
{

  // Trace backwards along trajectory (determined by current velocity)
  // distance = rate * time, but since the grid might not be unit-scale,
  // we need to also scale by the grid cell size.
  float2 pos = coords - timestep * rdx * f4texRECT(u, coords);

  // Example:
  //    the "particle" followed a trajectory and has landed like this:
  //
  //   (x1,y2)----(x2,y2)    (xN,yN)
  //      |          |    /----/  (trajectory: (xN,yN) = start, x = end)
  //      |          |---/
  //      |      /--/|    ^
  //      |  pos/    |     \_ v.xy (the velocity)
  //      |          |
  //      |          |
  //   (x1,y1)----(x2,y1)
  //
  // x1, y1, x2, and y2 are the coordinates of the 4 nearest grid points
  // around the destination.  We compute these using offsets and the floor
  // operator.  The "-0.5" and +0.5 used below are due to the fact that
  // the centers of texels in a TEXTURE_RECTANGLE_NV are at 0.5, 1.5, 2.5,
  // etc.

  // The function f4texRECTbilerp computes the above 4 points and interpolates
  // a value from texture lookups at each point.Rendering this value will
  // effectively place the interpolated value back at the starting point
  // of the advection.

  // So that we can have dissipating scalar fields (like smoke), we
  // multiply the interpolated value by a [0, 1] dissipation scalar
  // (1 = lasts forever, 0 = instantly dissipates.  At high frame rates,
  // useful values are in [0.99, 1].

  return dissipation * f4texRECTbilerp(x, pos);
}


//----------------------------------------------------------------------------
// Function     	: divergence
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program computes the divergence of the specified vector field
 * "velocity". The divergence is defined as
 *
 *  "grad dot v" = partial(v.x)/partial(x) + partial(v.y)/partial(y),
 *
 * and it represents the quantity of "stuff" flowing in and out of a parcel of
 * fluid.  Incompressible fluids must be divergence-free.  In other words
 * this quantity must be zero everywhere.
 */
void divergence(half2       coords  : WPOS,  // grid coordinates

           out  half4       div     : COLOR, // divergence (output)

        uniform half        halfrdx,         // 0.5 / gridscale
        uniform sampler2D w)               // vector field
{
  half4 vL, vR, vB, vT;
  h4texRECTneighbors(w, coords, vL, vR, vB, vT);

  div = halfrdx * (vR.x - vL.x + vT.y - vB.y);
}


//----------------------------------------------------------------------------
// Function     	: jacobi
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program performs a single Jacobi relaxation step for a poisson
 * equation of the form
 *
 *                Laplacian(U) = b,
 *
 * where U = (u, v) and Laplacian(U) is defined as
 *
 *   grad(div x) = grad(grad dot x) =
 *            partial^2(u)/(partial(x))^2 + partial^2(v)/(partial(y))^2
 *
 * A solution of the equation can be found iteratively, by using this
 * iteration:
 *
 *   U'(i,j) = (U(i-1,j) + U(i+1,j) + U(i,j-1) + U(i,j+1) + b) * 0.25
 *
 * That is what this routine does.  To maintain flexibility for slightly
 * different poisson problems (such as viscous diffusion), we provide
 * two parameters, centerFactor and stencilFactor.  These are useful for
 * non-unit-scale grids, and when there is a coefficient on the RHS of the
 * poisson equation.
 *
 * This program works for both scalar and vector equations.
 */
void jacobi(half2       coords : WPOS,
        out half4       xNew   : COLOR,
    uniform half        alpha,
    uniform half        rBeta, // reciprocal beta
    uniform sampler2D x,     // x vector (Ax = b)
    uniform sampler2D b)     // b vector (Ax = b)
{
  half4 xL, xR, xB, xT;
  h4texRECTneighbors(x, coords, xL, xR, xB, xT);
  half4 bC = h4texRECT(b, coords);
  xNew = (xL + xR + xB + xT + alpha * bC) * rBeta;
}


//----------------------------------------------------------------------------
// Function     	: gradient
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program implements the final step in the fluid simulation.  After
 * the poisson solver has iterated to find the pressure disturbance caused by
 * the divergence of the velocity field, the gradient of that pressure needs
 * to be subtracted from this divergent velocity to get a divergence-free
 * velocity field:
 *
 * v-zero-divergence = v-divergent -  grad(p)
 *
 * The gradient(p) is defined:
 *     grad(p) = (partial(p)/partial(x), partial(p)/partial(y))
 *
 * The discrete form of this is:
 *     grad(p) = ((p(i+1,j) - p(i-1,j)) / 2dx, (p(i,j+1)-p(i,j-1)) / 2dy)
 *
 * where dx and dy are the dimensions of a grid cell.
 *
 * This program computes the gradient of the pressure and subtracts it from
 * the velocity to get a divergence free velocity.
 */
void gradient(half2       coords  : WPOS,  // grid coordinates
          out half4       uNew    : COLOR, // divergence (output)//hvfFlo IN,
      uniform half        halfrdx,         // 0.5 / grid scale
      uniform sampler2D p,               // pressure
      uniform sampler2D w)               // velocity
{
  half pL, pR, pB, pT;
  h1texRECTneighbors(p, coords, pL, pR, pB, pT);
  half2 grad = half2(pR - pL, pT - pB) * halfrdx;
  uNew = h4texRECT(w, coords);
  uNew.xy -= grad;
}



//----------------------------------------------------------------------------
// Function     	: boundary
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program is used to compute neumann boundary conditions for solving
 * poisson problems.  The neumann boundary condition for the poisson equation
 * says that partial(u)/partial(n) = 0, where n is the normal direction of the
 * inside of the boundary.  This simply means that the value of the field
 * does not change across the boundary in the normal direction.
 *
 * In the case of our simple grid, this simply means that the value of the
 * field at the boundary should equal the value just inside the boundary.
 *
 * We allow the user to specify the direction of "just inside the boundary"
 * by using texture coordinate 1.
 *
 * Thus, to use this program on the left boundary, TEX1 = (1, 0):
 *
 * LEFT:   TEX1=( 1,  0)
 * RIGHT:  TEX1=(-1,  0)
 * BOTTOM: TEX1=( 0,  1)
 * TOP:    TEX1=( 0, -1)
 */
void boundary(half2       coords : WPOS,
              half2       offset : TEX1,
          out half4       bv     : COLOR,
      uniform half        scale,
      uniform sampler2D x)
{
  bv = scale * h4texRECT(x, coords + offset);
}

//----------------------------------------------------------------------------
// Function     	: updateOffsets
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program is used to compute boundary value lookup offsets for
 * implementing boundary conditions around arbitrary boundaries inside the
 * flow field.
 *
 * This program is run only when the arbitrary interior boundaries change.
 * Each cell can either be fluid or boundary.  A zero in the boundaries
 * texture indicates fluid, a 1 indicates boundary.
 *
 * The trick here is to use the boundary (0,1) values of the neighbors of a
 * cell to compute a single 4-vector containing the x and y offsets needed
 * to compute the correct boundary conditions.
 *
 * A clever encoding enables this.  A "stencil" is used to multiply and add
 * the neighbors and the center cell.  The stencil values are picked such
 * that each configuration has a unique value:
 *
 *    |   |  3 |   |
 *    | 7 | 17 | 1 |
 *    |   |  5 |   |
 *
 * The result is that we can precompute all possible configurations and store
 * the appropriate offsets for them (see Flo::_CreateOffsetTextures() in
 * flo.cpp) in a 1D lookup table texture.  Then we use this unique stencil
 * value as the texture coordinate.
 *
 * All of these texture reads (one per neighbor) are expensive, so we only
 * do this when the boundaries change, and then write them to an offset
 * texture.  Two lookups into this texture allow the arbitrary*Boundaries()
 * programs to compute pressure and velocity boundary values efficiently.
 *
 */
void updateOffsets(half2       coords : WPOS,
               out half4       offsets : COLOR,
           uniform sampler2D b,
           uniform sampler2D offsetTable)
{
  // get neighboring boundary values (on or off)
  half bW, bE, bN, bS;
  h1texRECTneighbors(b, coords, bW, bE, bS, bN);
  // center cell
  half bC = h1texRECT(b, coords);

  // compute offset lookup index by adding neighbors...
  // the strange offsets ensure a unique index for each possible configuration
  half index = 3 * bN + bE + 5 * bS + 7 * bW + 17 * bC;

  // get scale and offset = (uScale, uOffset, vScale, vOffset)
  offsets = h4texRECT(offsetTable, index);
}

//----------------------------------------------------------------------------
// Function     	: arbitraryVelocityBoundary
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program uses the offset texture computed by the program above to
 * implement arbitrary no-slip velocity boundaries.  It is essentially the
 * same in operation as the edge boundary program above, but it requires
 * an initial texture lookup to get the offsets (they can't be provided as
 * a uniform parameter because they change at each cell).  It must then offset
 * differently in x and y, so it requires two lookups to compute the boundary
 * values.
 */
void arbitraryVelocityBoundary(half2       coords : WPOS,
                           out half4       uNew   : COLOR,
                       uniform sampler2D u,
                       uniform sampler2D offsets)
{
  // get scale and offset = (uScale, uOffset, vScale, vOffset)
  half4 scaleoffset = h4texRECT(offsets, coords);

  // compute the x boundary value
  uNew.x = scaleoffset.x * h1texRECT(u, coords + half2(0, scaleoffset.y));
  // compute the y boundary value
  uNew.y = scaleoffset.z * h2texRECT(u, coords + half2(scaleoffset.w, 0)).y;
  uNew.zw = 0;
}

//----------------------------------------------------------------------------
// Function     	: arbitraryPressureBoundary
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program is used to implement pure-neumann pressure boundary conditions
 * around arbitrary boundaries.  This program operates in essentially the same
 * manner as arbitraryVelocityBoundary, above.
 */
void arbitraryPressureBoundary(half2       coords : WPOS,
                           out half4       pNew   : COLOR,
                       uniform sampler2D p,
                       uniform sampler2D offsets)
{
  // get the two neighboring pressure offsets
  // they will be the same if this is N, E, W, or S, different if NE, SE, etc.
  half4 offset = h4texRECT(offsets, coords);

  pNew = 0.5 * (h1texRECT(p, coords + offset.xy) +
                h1texRECT(p, coords + offset.zw));
}



//----------------------------------------------------------------------------
// Vorticity Confinement
//----------------------------------------------------------------------------
// The motion of smoke, air and other low-viscosity fluids typically contains
// rotational flows at a variety of scales. This rotational flow is called
// vorticity.  As Fedkiw et al. explained (2001), numerical dissipation caused
// by simulation on a coarse grid damps out these interesting features.
// Therefore, they used "vorticity confinement" to restore these fine-scale
// motions. Vorticity confinement works by first computing the vorticity,
//                          vort = curl(u).
// The program vorticity() does this computation. From the vorticity we
// compute a normalized vorticity vector field,
//                          F = normalize(eta),
// where, eta = grad(|vort|). The vectors in F point from areas of lower
// vorticity to areas of higher vorticity. From these vectors we compute a
// force that can be used to restore an approximation of the dissipated
// vorticity:
//                          vortForce = eps * cross(F, vort) * dx.
// Here eps is a user-controlled scale parameter.
//
// The operations above require two passes in the simulator.  This is because
// the vorticity must be computed in one pass, because computing the vector
// field F requires sampling multiple vorticity values for each vector.
// Because a texture can't be written and then read in a single pass, this is
// inherently a two-pass algorithm.

//----------------------------------------------------------------------------
// Function     	: vorticity
// Description	    :
//----------------------------------------------------------------------------
/**
    The first pass of vorticity confinement computes the (scalar) vorticity
    field.  See the description above.  In Flo, if vorticity confinement is
    disabled, but the vorticity field is being displayed, only this first
    pass is executed.
 */
void vorticity(half2       coords : WPOS,
           out half        vort   : COLOR,
       uniform half        halfrdx, // 0.5 / gridscale
       uniform sampler2D u)       // velocity
{
  half4 uL, uR, uB, uT;
  h4texRECTneighbors(u, coords, uL, uR, uB, uT);
  vort = halfrdx * ((uR.y - uL.y) - (uT.x - uB.x));
}



//----------------------------------------------------------------------------
// Function     	: vortForce
// Description	    :
//----------------------------------------------------------------------------
/**
    The second pass of vorticity confinement computes a vorticity confinement
    force field and applies it to the velocity field to arrive at a new
    velocity field.
 */
void vortForce(half2       coords : WPOS,
           out half2       uNew   : COLOR,
       uniform half        halfrdx,  // 0.5 / gridscale
       uniform half2       dxscale,  // vorticity confinement scale
       uniform half        timestep,
       uniform sampler2D vort,     // vorticity
       uniform sampler2D u)        // velocity
{
  half vL, vR, vB, vT, vC;
  h1texRECTneighbors(vort, coords, vL, vR, vB, vT);
  vC = h1texRECT(vort, coords);
  half2 force = halfrdx * half2(abs(vT) - abs(vB), abs(vR) - abs(vL));

  // safe normalize
  static const half EPSILON = 2.4414e-4; // 2^-12
  half magSqr = max(EPSILON, dot(force, force));
  force = force * rsqrt(magSqr);
  force *= dxscale * vC * half2(1, -1);
  uNew = h2texRECT(u, coords);
  uNew += timestep * force;
}


//----------------------------------------------------------------------------
// Function     	: display[Scalar | Vector][Bilerp]
// Description	    :
//----------------------------------------------------------------------------
/**
 * The following four programs simply display rectangle textures.  A fragment
 * program is required on NV3X to display floating point textures.  The scale
 * and bias parameters allow the manipulation of the values in the texture
 * before display.  This is useful, for example, if the values in the texture
 * are signed.  A scale and bias of 0.5 can bring the range [-1, 1] into the
 * range [0, 1] for  for visualization or other purposes.
 *
 * The four versions of the program are for displaying with and without
 * bilinear interpolation (smoothing), and for scalar and vector textures.
 */

// displayScalar
void displayScalar(half2       coords : TEX0,
               out half4       color  : COLOR,
           uniform half4       scale,
           uniform half4       bias,
           uniform sampler2D tex)
{
  color = bias + scale * h4texRECT(tex, coords).xxxx;
}

// displayVector
void displayVector(half2       coords : TEX0,
               out half4       color  : COLOR,
           uniform half4       scale,
           uniform half4       bias,
           uniform sampler2D tex)
{
  color = bias + scale * h4texRECT(tex, coords);
}

// displayScalarBilerp
void displayScalarBilerp(half2       coords : TEX0,
                     out half4       color : COLOR,
                 uniform half4       scale,
                 uniform half4       bias,
                 uniform sampler2D tex)
{
  color = bias + scale * h1texRECTbilerp(tex, coords);
}

// displayVectorBilerp
void displayVectorBilerp(half2       coords : TEX0,
                     out half4       color : COLOR,
                 uniform half4       scale,
                 uniform half4       bias,
                 uniform sampler2D tex)
{
  color = bias + scale * h4texRECTbilerp(tex, coords);
}


#endif