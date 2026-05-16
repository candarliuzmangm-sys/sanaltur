'use client';

import { Canvas } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import { Suspense } from 'react';
import * as THREE from 'three';

interface Props {
  imageUrl: string;
}

function PanoramaSphere({ imageUrl }: { imageUrl: string }) {
  const texture = new THREE.TextureLoader().load(imageUrl);
  return (
    <mesh>
      <sphereGeometry args={[500, 60, 40]} />
      <meshBasicMaterial map={texture} side={THREE.BackSide} />
    </mesh>
  );
}

export function PanoramaScene({ imageUrl }: Props) {
  return (
    <Canvas style={{ width: '100%', height: '100%', minHeight: 400 }}>
      <Suspense fallback={null}>
        <PanoramaSphere imageUrl={imageUrl} />
        <OrbitControls enableZoom={false} rotateSpeed={-0.3} />
      </Suspense>
    </Canvas>
  );
}
